"""Editable, mesh-only Zhili courtyard wayfinding. Coordinates are in metres.

The small C pier plaque and the L2 landing marker follow the psychology school
entrance photo and SUIADR courtyard photo 2021051077344. The freestanding
fingerpost is original game wayfinding. SZU's Information Center confirms the
service hall is on C's ground floor (https://it.szu.edu.cn/zzjg/xxfwb.htm).
"""

from math import cos, pi, sin
from pathlib import Path

import bpy


COLLECTION = "Street | Zhili wayfinding"
FINISHES = {
    "enamel": ("344a4b", .22, .39),
    "reverse": ("536566", .45, .42),
    "alloy": ("adb2ac", .80, .38),
    "steel": ("606b6a", .76, .46),
    "gasket": ("252b2a", .08, .85),
    "ivory": ("eaeada", .08, .45),
    "sage": ("b4ccbd", .15, .42),
    "ochre": ("d6b684", .15, .42),
}


def _materials():
    result = {}
    for finish, (hex_color, metallic, roughness) in FINISHES.items():
        name = "Zhili sign / " + finish
        material = bpy.data.materials.get(name)
        if not material:
            material = bpy.data.materials.new(name)
            srgb = [int(hex_color[i:i + 2], 16) / 255 for i in (0, 2, 4)]
            linear = [v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in srgb]
            material.diffuse_color = (*linear, 1)
            material.use_nodes = True
            shader = next(node for node in material.node_tree.nodes if node.type == 'BSDF_PRINCIPLED')
            shader.inputs["Base Color"].default_value = material.diffuse_color
            shader.inputs["Metallic"].default_value = metallic
            shader.inputs["Roughness"].default_value = roughness
        result[finish] = material
    return result


def _letter_font():
    paths = (
        "C:/Windows/Fonts/SourceHanSansSC-Medium.ttf",
        "C:/Windows/Fonts/msyh.ttc",
        "/System/Library/Fonts/PingFang.ttc",
        "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
    )
    for path in paths:
        if Path(path).is_file():
            return bpy.data.fonts.load(path, check_existing=True)
    raise RuntimeError("A Chinese font is required for the Zhili directions.")


class _Assembly:
    """One local-space mesh per fixture so each prop remains editable and movable."""

    def __init__(self, name, origin, collection, materials, font):
        self.name, self.origin = name, origin
        self.collection, self.materials, self.font = collection, materials, font
        self.vertices, self.faces, self.finishes = [], [], []

    def mesh(self, vertices, faces, finish):
        start = len(self.vertices)
        self.vertices.extend(vertices)
        for face in faces:
            self.faces.append(tuple(start + i for i in face))
            self.finishes.append(finish)

    def plate(self, outline, y, depth, finish):
        # A counter-clockwise X/Z face has its normal pointing toward the courtyard (-Y).
        area = sum(x0 * z1 - x1 * z0 for (x0, z0), (x1, z1)
                   in zip(outline, outline[1:] + outline[:1]))
        if area < 0:
            outline = outline[::-1]
        n = len(outline)
        verts = [(x, y + offset, z) for offset in (0, depth) for x, z in outline]
        faces = [tuple(range(n)), tuple(reversed(range(n, 2 * n)))]
        faces += [((i + 1) % n, i, i + n, (i + 1) % n + n) for i in range(n)]
        self.mesh(verts, faces, finish)

    def rectangle(self, x, y, z, width, depth, height, finish, chamfer=0):
        a, b = x - width / 2, x + width / 2
        top = z + height
        if chamfer:
            c = chamfer
            outline = [(a+c,z), (b-c,z), (b,z+c), (b,top-c),
                       (b-c,top), (a+c,top), (a,top-c), (a,z+c)]
        else:
            outline = [(a,z), (b,z), (b,top), (a,top)]
        self.plate(outline, y, depth, finish)

    def fastener(self, x, y, z, radius=.011):
        # A countersunk head with a real slotted dark recess on the front face.
        head = [(x + radius*cos(i*pi/6), z + radius*sin(i*pi/6)) for i in range(12)]
        self.plate(head, y, .003, "alloy")
        self.plate([(x-.61*radius,z-.31*radius), (x+.52*radius,z+.43*radius),
                    (x+.62*radius,z+.30*radius), (x-.50*radius,z-.44*radius)],
                   y-.0006, .0004, "gasket")

    def text(self, body, x, y, z, max_width, height, finish):
        # Flatten print at its true design size. Vector outlines survive GLB export
        # and keep the result independent of a font install on the user's phone.
        curve = bpy.data.curves.new("Wayfinding typeset", "FONT")
        curve.font, curve.body, curve.resolution_u = self.font, body, 3
        source = bpy.data.objects.new("Wayfinding typeset", curve)
        self.collection.objects.link(source)
        evaluated = source.evaluated_get(bpy.context.evaluated_depsgraph_get())
        mesh = evaluated.to_mesh()
        try:
            points = [v.co.copy() for v in mesh.vertices]
            if not points:
                raise RuntimeError("No glyph geometry for " + body)
            x0, x1 = min(p.x for p in points), max(p.x for p in points)
            y0, y1 = min(p.y for p in points), max(p.y for p in points)
            scale = min(max_width / (x1 - x0), height / (y1 - y0))
            self.mesh([(x+(p.x-x0)*scale, y, z+(p.y-y0)*scale) for p in points],
                      [tuple(f.vertices) for f in mesh.polygons], finish)
        finally:
            evaluated.to_mesh_clear()
            bpy.data.objects.remove(source, do_unlink=True)
            bpy.data.curves.remove(curve)

    def finish(self):
        mesh = bpy.data.meshes.new(self.name)
        mesh.from_pydata(self.vertices, [], self.faces)
        mesh.update()
        used = list(dict.fromkeys(self.finishes))
        slots = {key: i for i, key in enumerate(used)}
        for key in used:
            mesh.materials.append(self.materials[key])
        mesh.polygons.foreach_set("material_index", [slots[key] for key in self.finishes])
        obj = bpy.data.objects.new(self.name, mesh)
        self.collection.objects.link(obj)
        obj.location = self.origin
        return obj


def _fingerpost(prop):
    # Square alloy extrusion, closed cap, expansion joint, sole plate and anchor nuts.
    prop.rectangle(0,-.105,0,.22,.21,.018,"gasket")
    prop.rectangle(0,-.11,.018,.23,.22,.015,"steel")
    for x in (-.078, .078):
        for y in (-.071, .071):
            prop.rectangle(x,y-.009,.033,.02,.018,.011,"alloy",.003)
    prop.rectangle(0,-.046,.033,.09,.092,2.27,"steel",.003)
    prop.rectangle(0,-.047,2.303,.092,.094,.010,"alloy",.004)
    prop.rectangle(0,-.049,.036,.097,.098,.15,"reverse",.004)
    for side, z, tint, title, sub in (
        (-1,1.94,"sage","致理楼 C","一层 · 信息中心服务大厅"),
        (1,1.64,"ochre","致理楼 B","台阶 · 上层平台"),
    ):
        # Cantilevered folded sheet on a removable rear clamp, with a cut corner
        # pointing toward the actual destination. Writing is upright on both arms.
        outline = [(side*u, z+v) for u,v in ((.023,0),(.90,0),(.977,.077),
                                              (.977,.239),(.946,.27),(.023,.27))]
        prop.rectangle(side*.054,-.042,z+.045,.157,.104,.18,"alloy",.008)
        prop.plate(outline, -.075, .042, "reverse")
        prop.plate(outline, -.077, .003, "enamel")
        arrow_x = side*.865
        arrow = [(-.035,0),(.003,0),(.003,-.020),(.039,.009),
                 (.003,.038),(.003,.018),(-.035,.018)]
        prop.plate([(arrow_x+side*u,z+.143+v) for u,v in arrow],-.0785,.001,"ivory")
        left = -.748 if side < 0 else .126
        prop.text(title,left,-.0785,z+.126,.61,.078,"ivory")
        prop.text(sub,left,-.0785,z+.053,.646,.041,tint)
        prop.fastener(side*.055,-.080,z+.043,.008)
        prop.fastener(side*.055,-.080,z+.228,.008)
    prop.finish()


def _pier_plate(prop):
    prop.rectangle(0,-.015,0,.439,.014,.218,"gasket",.008)
    prop.rectangle(0,-.022,.003,.434,.009,.212,"alloy",.008)
    prop.rectangle(0,-.023,.011,.416,.001,.195,"ivory",.005)
    prop.text("致理楼 C",-.174,-.024,.073,.348,.074,"enamel")
    for x in (-.197, .197):
        prop.fastener(x,-.025,.106,.005)
    prop.finish()


def _landing_marker(prop):
    # Pale level badge visible against the parapet in the architect's photo.
    prop.rectangle(0,-.034,0,.40,.034,.58,"alloy",.009)
    prop.rectangle(0,-.036,.008,.384,.002,.564,"ivory",.004)
    prop.text("L2",-.133,-.037,.137,.267,.264,"enamel")
    for x in (-.162, .162):
        for z in (.035, .545):
            prop.fastener(x,-.039,z,.007)
    prop.finish()


def add_signs():
    collection = bpy.data.collections.get(COLLECTION)
    if collection:
        if collection.get("zhili_wayfinding") == 1:
            return collection
        raise ValueError("Unrelated collection already uses " + COLLECTION)
    font, finishes = _letter_font(), _materials()
    collection = bpy.data.collections.new(COLLECTION)
    bpy.context.scene.collection.children.link(collection)
    try:
        for make, name, origin in (
            (_fingerpost, "C–B | Courtyard directions", (23.2,-17.6,.12)),
            (_pier_plate, "C | Outer pier identifier", (17.85,-14.337,3.24)),
            (_landing_marker, "B | Landing L2 badge", (29.45,-8.622,5.94)),
        ):
            make(_Assembly(name, origin, collection, finishes, font))
    except Exception:
        for obj in list(collection.objects):
            data = obj.data
            bpy.data.objects.remove(obj, do_unlink=True)
            if isinstance(data, bpy.types.Mesh) and not data.users:
                bpy.data.meshes.remove(data)
        bpy.data.collections.remove(collection)
        raise
    collection["zhili_wayfinding"] = 1
    return collection
