"""Metre-scaled facade finishes shared by Cycles and the mobile glTF.

The axial UV projection aligns drip marks with gravity on both returns of a pier.
Tiles are made here from seeded noise, with no photographs baked onto the walls.
"""
from pathlib import Path
import struct
import zlib

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree


def periodic_noise(rng, size, rows, cols):
    grid = rng.uniform(-1, 1, (rows, cols))
    yy, xx = np.mgrid[:size, :size]
    x, y = xx * cols / size, yy * rows / size
    i, j = np.floor(x).astype(int), np.floor(y).astype(int)
    u, v = x - i, y - j
    u, v = u*u*(3-2*u), v*v*(3-2*v)
    row = (1-u)*grid[j, i] + u*grid[j, (i+1)%cols]
    following = (1-u)*grid[(j+1)%rows, i] + u*grid[(j+1)%rows, (i+1)%cols]
    return (1-v)*row + v*following


def write_png(target, image):
    def chunk(tag, content):
        return struct.pack(">I", len(content))+tag+content+struct.pack(">I", zlib.crc32(tag+content))
    height, width, _ = image.shape
    raw = b"".join(b"\x00"+line.tobytes() for line in image)
    head = struct.pack(">2I5B", width, height, 8, 2, 0, 0, 0)
    target.write_bytes(b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR", head)+chunk(b"IDAT", zlib.compress(raw, 8))+chunk(b"IEND", b""))


def make_tile(folder, name, base, family, seed):
    size = 384
    rng = np.random.default_rng(seed)
    noise = lambda rows, cols: periodic_noise(rng, size, rows, cols)
    broad = noise(4, 5)*.53 + noise(12, 14)*.30 + noise(31, 33)*.17
    grain = rng.normal(0, 1, (size, size))
    if family == "paint":
        # Rainborne dust travels down pale rendered walls in irregular fine runs.
        drip = np.maximum(0, noise(2, 66)-.23) * (.55+.45*noise(5, 4))
        gain = .983 + .05*broad - .16*drip + .008*grain
    elif family == "basalt":
        flecks = np.maximum(0, grain-1.3) - np.maximum(0, -grain-1.3)
        gain = .97 + .16*broad + .15*flecks + .05*grain
    elif family == "grass":
        gain = 1.0 + .24*broad + .12*noise(63, 53) + .085*grain
    elif family == "bark":
        gain = .98 + .19*broad + .21*noise(5,67) + .11*noise(14,112) + .047*grain
    else:
        gain = .99 + .12*broad + .041*grain
        if family == "paving":
            yy, xx = np.mgrid[:size, :size]
            # 900 x 450 mm units, alternating half bond, narrow recessed grout.
            row = yy // (size//4)
            joint = (yy % (size//4) < 1) | ((xx+row*(size//4)) % (size//2) < 1)
            gain[joint] *= .66
    srgb = np.array([12.92*v if v<=.0031308 else 1.055*v**(1/2.4)-.055 for v in base])
    rgb = np.clip(255*srgb[None,None,:]*gain[:,:,None], 0, 255).astype(np.uint8)
    target = folder/(name+".png")
    write_png(target, rgb)
    return target


def apply_to_game_meshes(folder):
    families = {"paint":("porcelain","chalkwhite","reveal","soffit"),
                "basalt":("granite","granite2"), "sandstone":("ashlar","ashlar2"),
                "stone":("stairrose","stairrose2"), "bark":("bark",),
                "paving":("paver1","paver2","paver3"), "grass":("meadow",)}
    metric = {"paint":3.4,"basalt":1.1,"sandstone":2.3,"paving":1.8,"grass":1.5,"stone":.93,"bark":.65}
    texture_dir = Path(folder)/"surfaces"
    texture_dir.mkdir(exist_ok=True)
    scales = {}
    for family, names in families.items():
        for index, name in enumerate(names):
            material = bpy.data.materials.get(name)
            if not material: continue
            scales[name] = metric[family]
            path = make_tile(texture_dir, name, material.diffuse_color[:3], family, 610+index)
            image = bpy.data.images.load(str(path))
            image.pack()
            nodes, links = material.node_tree.nodes, material.node_tree.links
            surface = nodes.get("Principled BSDF")
            tex = nodes.new("ShaderNodeTexImage"); tex.image = image
            links.new(tex.outputs["Color"], surface.inputs["Base Color"])
            surface.inputs["Roughness"].default_value = .68 if family=="basalt" else .82
    for obj in bpy.context.scene.objects:
        if obj.type!="MESH" or not obj.data.materials: continue
        scale = scales.get(obj.data.materials[0].name)
        if not scale: continue
        mesh = obj.data
        uv = mesh.uv_layers.new(name="Metres")
        for face in mesh.polygons:
            if mesh.materials[0].name=="bark":face.use_smooth=True
            axis = max(range(3), key=lambda i: abs(face.normal[i]))
            for i in face.loop_indices:
                x, y, z = mesh.vertices[mesh.loops[i].vertex_index].co
                a, b = (y,z) if axis==0 else (x,z) if axis==1 else (x,y)
                uv.data[i].uv = (a/scale,b/scale)
    bake_arcade_shade()


def bake_arcade_shade():
    # Partial sky visibility gives the GLB some bounced-light contrast even on
    # phones with a single small shadow map. Cycles computes its own occlusion.
    solids = [o for o in bpy.context.scene.objects if o.type=="MESH" and not
              o.name.startswith(("Lettering","Planting","Court | Paving"))]
    vertices=[]; polygons=[]
    for obj in solids:
        mesh=obj.data; offset=len(vertices)
        vertices.extend(v.co.copy() for v in mesh.vertices)
        polygons.extend(tuple(offset+i for i in p.vertices) for p in mesh.polygons)
    tree=BVHTree.FromPolygons(vertices,polygons)
    directions=[Vector(v).normalized() for v in ((.1,.1,1),(.6,.6,.85),(-.6,.6,.85),
                (.6,-.6,.85),(-.6,-.6,.85),(.9,0,.4),(-.9,0,.4),(0,.9,.4),(0,-.9,.4))]
    for obj in solids:
        mesh=obj.data
        if not mesh.materials or mesh.materials[0].name.startswith("sign"): continue
        if len(mesh.polygons)<2:continue
        attr=mesh.color_attributes.new(name="Courtyard occlusion",type="BYTE_COLOR",domain="CORNER")
        mesh.color_attributes.active_color=attr
        cache={}
        for face in mesh.polygons:
            normal=face.normal
            axis=tuple(round(v,2) for v in normal)
            for loop in face.loop_indices:
                vertex=mesh.loops[loop].vertex_index
                key=(vertex,axis)
                if key not in cache:
                    origin=mesh.vertices[vertex].co + normal*.045
                    blocked=weight=0.
                    for ray in directions:
                        dot=normal.dot(ray)
                        if dot < -.22: continue
                        w=.35+max(0,dot)
                        hit=tree.ray_cast(origin,ray,13)[3]
                        if hit is not None:blocked+=w*(1-hit/13)
                        weight+=w
                    shade=1-.50*blocked/weight if weight else .72
                    cache[key]=(shade,shade,shade,1.)
                attr.data[loop].color=cache[key]
