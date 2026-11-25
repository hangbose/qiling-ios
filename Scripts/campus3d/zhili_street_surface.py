"""Ground-level details for the two Zhili entrances, in the campus metre grid.

The C entrance photograph shows pale slabs, a clipped lawn and a drain beside
the path. The B approach photograph shows an irregular sett band below its
terracotta steps. Utility furniture and joint spacing are interpretations.
"""

import math
import random
import struct
import tempfile
import zlib
from pathlib import Path

import bpy
import numpy as np


COLLECTION = "Zhili | Arrival court surfaces"
SLOTS = (
    # sRGB grain colour, roughness, metallic. Each row has an atlas swatch.
    ("Flamed granite", (173, 170, 157), .85, 0.0),
    ("Dark granite sett", (140, 138, 125), .80, 0.0),
    ("Damp stone edge", (131, 131, 119), .47, 0.0),
    ("Cut kerbstone", (185, 180, 162), .78, 0.0),
    ("Bed joint", (97, 95, 85), .96, 0.0),
    ("Grate / cast iron", (82, 84, 77), .52, .62),
    ("Recess / silt", (48, 48, 42), .91, .05),
    ("Worn stamped metal", (116, 116, 99), .44, .60),
)


def _aggregate_materials():
    """Pack a PBR-compatible flecked stone/almost-black foundry metal atlas."""
    prefix = "Zhili arrival / "
    def initialized(material):
        return material and material.get("zhili_atlas_bound", False)

    if all(initialized(bpy.data.materials.get(prefix + slot[0])) for slot in SLOTS):
        return [bpy.data.materials[prefix + slot[0]] for slot in SLOTS]

    image_name = "Zhili arrival - quarried surface atlas"
    atlas = bpy.data.images.get(image_name)
    if atlas is None:
        side = 192
        rng = np.random.default_rng(72917)
        pixels = np.zeros((side * 2, side * 4, 3), dtype=np.uint8)
        for i, (_, base, _, _) in enumerate(SLOTS):
            # Crushed quartz flecks over a softer mineral matrix, shared per batch.
            fine = rng.normal(0.0, 3.5 if i < 4 else 2.0, (side, side))
            coarse = rng.normal(0.0, 1.8, (side // 8, side // 8))
            for axis in (0, 1):
                coarse = np.repeat(coarse, 8, axis=axis)
                coarse = sum(np.roll(coarse, j, axis=axis) for j in range(5)) / 5
            seed = rng.random((side, side))
            inclusions = np.where(seed < .034, -22.0, np.where(seed > .965, 16.0, 0.0))
            tone = fine + coarse + (inclusions + .48 * np.roll(inclusions, 1, 1)) * (1 if i < 4 else .5)
            patch = np.clip(np.array(base) + tone[:, :, None], 0, 255).astype(np.uint8)
            col, row = i % 4, 1 - i // 4
            pixels[row*side:(row+1)*side, col*side:(col+1)*side] = patch

        def chunk(kind, data):
            return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

        height, width = pixels.shape[:2]
        header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
        data = b"".join(b"\0" + row.tobytes() for row in pixels)
        png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(data, 7)) + chunk(b"IEND", b"")
        with tempfile.TemporaryDirectory() as path:
            texture_path = Path(path) / "zhili_arrival_grain.png"
            texture_path.write_bytes(png)
            atlas = bpy.data.images.load(str(texture_path))
            atlas.name = image_name
            atlas.pack()
            atlas.filepath = "//zhili_arrival_grain.png"

    materials = []
    for name, base, roughness, metallic in SLOTS:
        material = bpy.data.materials.get(prefix + name)
        if not initialized(material):
            if material is None:
                material = bpy.data.materials.new(prefix + name)
            material.use_nodes = True
            material.diffuse_color = tuple(((c / 255 + .055) / 1.055) ** 2.4 for c in base) + (1.0,)
            shader = next(node for node in material.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
            shader.inputs["Roughness"].default_value = roughness
            shader.inputs["Metallic"].default_value = metallic
            texture = material.node_tree.nodes.new("ShaderNodeTexImage")
            texture.image = atlas
            material.node_tree.links.new(texture.outputs["Color"], shader.inputs["Base Color"])
            material["zhili_atlas_bound"] = True
        materials.append(material)
    return materials


class SurfaceBatch:
    def __init__(self, name, collection, materials, rng):
        self.name, self.collection, self.materials, self.rng = name, collection, materials, rng
        self.verts, self.faces, self.face_slots, self.uvs = [], [], [], []

    def face(self, indices, slot, origin):
        self.faces.append(indices)
        self.face_slots.append(slot)
        # Repeat at component boundaries; a 1 cm atlas gutter prevents mip bleed.
        x, y, du, dv, scale = origin
        self.uvs.append([((slot % 4 + .02 + du + (self.verts[j][0]-x) * scale) / 4,
                          (slot // 4 + .02 + dv + (self.verts[j][1]-y) * scale) / 2)
                         for j in indices])

    def plate(self, x, y, width, depth, top, slot, bevel=.004, rise=.002):
        x0, y0 = x-width/2, y-depth/2
        x1, y1 = x+width/2, y+depth/2
        start = len(self.verts)
        edge = min(bevel, width * .15, depth * .15)
        uv = (x0, y0, self.rng.random()*.20, self.rng.random()*.20, min(.73/max(width, depth), 1.15))
        self.verts.extend([(x0,y0,top-rise),(x1,y0,top-rise),(x1,y1,top-rise),(x0,y1,top-rise)])
        if edge == 0:
            self.face(tuple(range(start, start+4)), slot, uv)
            return
        self.verts.extend([(x0+edge,y0+edge,top),(x1-edge,y0+edge,top),
                           (x1-edge,y1-edge,top),(x0+edge,y1-edge,top)])
        self.face(tuple(range(start+4, start+8)), slot, uv)
        for j in range(4):
            k = (j+1) % 4
            self.face((start+j, start+k, start+k+4, start+j+4), slot, uv)

    def disc(self, x, y, radius, top, slot, n=8):
        start = len(self.verts)
        uv = (x-radius, y-radius, .2, .2, min(1.0, .25/radius))
        for i in range(n):
            a = math.tau * i/n
            self.verts.append((x + radius*math.cos(a), y + radius*math.sin(a), top))
        self.face(tuple(range(start, start+n)), slot, uv)

    def finish(self):
        mesh = bpy.data.meshes.new(self.name)
        mesh.from_pydata(self.verts, [], self.faces)
        mesh.update()
        used = sorted(set(self.face_slots))
        for slot in used:
            mesh.materials.append(self.materials[slot])
        mesh.polygons.foreach_set("material_index", [used.index(slot) for slot in self.face_slots])
        coords = np.array([uv for face in self.uvs for uv in face], dtype=np.float32)
        layer = mesh.uv_layers.new(name="UVMap")
        layer.data.foreach_set("uv", coords.ravel())
        obj = bpy.data.objects.new(self.name, mesh)
        self.collection.objects.link(obj)
        return obj


def _course(batch, x0, x1, y, depth, nominal, stagger, base, slots, rng, gap):
    # A full-width backing visible in the narrow mortar gaps grounds the stones.
    batch.plate((x0+x1)/2, y, x1-x0, depth, base, 4, 0, 0)
    x = x0 - stagger
    while x < x1:
        length = nominal * rng.uniform(.86, 1.14)
        left, right = max(x0, x), min(x1, x+length)
        if right-left > gap * 2:
            batch.plate((left+right)/2, y, right-left-gap, depth-gap,
                        base + rng.uniform(.0035, .0055), rng.choice(slots))
        x += length


def _drain(batch, x, y0, panels):
    # Actual openings between lateral bars, over a recessed shadow tray.
    # Both fixing flanges and the four bolt heads belong to each 60 cm casting.
    for i in range(panels):
        y = y0 + .60 * (i+.5)
        batch.plate(x, y, .300, .595, .147, 6, 0, 0)
        for dx in (-.138, .138):
            batch.plate(x+dx, y, .018, .591, .157, 5, .002, .007)
        for dy in (-.283, .283):
            batch.plate(x, y+dy, .280, .017, .158, 5, .002, .006)
        batch.plate(x-.012, y, .018, .57, .152, 5)
        for j in range(11):
            batch.plate(x, y-.248+j*.0495, .265, .023, .159, 5, .003, .008)
        for dx in (-.133, .133):
            for dy in (-.252, .252):
                batch.disc(x+dx, y+dy, .006, .159, 7)


def _service_lid(batch, x, y):
    batch.plate(x, y, .66, .60, .143, 6, .009, .008)
    batch.plate(x, y, .625, .565, .149, 5, .006, .006)
    for dx in (-.273, .273):
        batch.plate(x+dx, y, .018, .112, .151, 6, .003)
    # Short parallel traction ribs alternate direction from one square to the next.
    for i in range(5):
        for j in range(5):
            for line in (-.021, .0, .021):
                xx, yy = x+(i-2)*.096, y+(j-2)*.095
                if (i+j) % 2:
                    batch.plate(xx+line, yy, .007, .057, .152, 5, .001)
                else:
                    batch.plate(xx, yy+line, .057, .007, .152, 5, .001)


def add_surfaces():
    """Add exportable surface details; repeated calls reuse the same collection."""
    previous = bpy.data.collections.get(COLLECTION)
    if previous:
        return previous
    collection = bpy.data.collections.new(COLLECTION)
    bpy.context.scene.collection.children.link(collection)
    try:
        materials = _aggregate_materials()
        rng = random.Random(9721)
        c = SurfaceBatch("C court | stone edges and flush path", collection, materials, rng)
        for cx, width, depth in [(-23, 22, 9), (2, 19, 10)]:
            # Dress the original kerb, leaving its lawn level and footprint intact.
            for sign in (-1, 1):
                _course(c, cx-width/2-.127, cx+width/2+.127,
                        -22+sign*(depth/2+.067), .129, .81, 0, .211, [3], rng, .008)
                pos, end = -22-depth/2, -22+depth/2
                while pos < end-.001:
                    length = min(end-pos, .80)
                    c.plate(cx+sign*(width/2+.067), pos+length/2, .13, length-.008, .217, 3)
                    pos += length
        # The narrow C path travels along the lawn toward the covered entrance.
        for k in range(18):
            _course(c, 12.12, 15.60, -27.80 + k*.625, .625, .96, (k%2)*.46,
                    .143, [0,0,0,3], rng, .005)
        # Darkened cut stones at the drain line give the gutter a damp edge.
        for k in range(17):
            c.plate(12.035, -27.80+k*.64, .15, .632, .149, rng.choice([2,2,0]))
        c.finish()

        b = SurfaceBatch("B stair | granite sett crossing and landing", collection, materials, rng)
        for k in range(8):
            _course(b, 22.95, 44.10, -25.12+k*.155, .155, .235, (k%2)*.11,
                    .123, [1,1,1,2], rng, .009)
        # The pale apron abuts the bottom tread and contrasts with its warm granite.
        for k in range(6):
            _course(b, 30.69, 42.31, -23.80+k*.526, .526, 1.08, (k%2)*.52,
                    .126, [0,0,0,3], rng, .005)
        b.finish()

        metal = SurfaceBatch("C court | storm drain and access covers", collection, materials, rng)
        _drain(metal, 11.81, -27.72, 17)
        _service_lid(metal, 14.34, -19.40)
        _service_lid(metal, 28.4, -22.38)
        metal.finish()
        return collection
    except Exception:
        for obj in list(collection.objects):
            mesh = obj.data
            bpy.data.objects.remove(obj, do_unlink=True)
            if mesh.users == 0:
                bpy.data.meshes.remove(mesh)
        bpy.data.collections.remove(collection)
        raise
