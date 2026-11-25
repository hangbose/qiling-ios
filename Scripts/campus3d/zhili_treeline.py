"""Peripheral planting and background blocks for ground-level views, in metres."""
import math
import bpy
from zhili_bicycles import finish


def crown_mesh(scene):
    # Reuse the original courtyard tree. Weld the five materials into one shared
    # asset and simplify once, before placing the trees at the far edge of the walk.
    vertices, triangles, indices, materials = [], [], [], []
    tree_pieces = [o for o in scene.objects if o.name.startswith("Planting | canopy (-38,-21)-")]
    if not tree_pieces:
        raise RuntimeError("The exterior studio scene must contain its courtyard tree.")
    for part in tree_pieces:
        mesh = part.data
        start = len(vertices)
        mat = mesh.materials[0]
        if mat not in materials:
            materials.append(mat)
        slot = materials.index(mat)
        vertices.extend((v.co.x+38, v.co.y+21, v.co.z-.13) for v in mesh.vertices)
        mesh.calc_loop_triangles()
        for tri in mesh.loop_triangles:
            triangles.append(tuple(start+i for i in tri.vertices))
            indices.append(slot)
    mesh = bpy.data.meshes.new("Peripheral court tree")
    mesh.from_pydata(vertices,[],triangles)
    for mat in materials:
        mesh.materials.append(mat)
    mesh.polygons.foreach_set("material_index",indices)
    original = bpy.data.objects.new("Tree detail source",mesh)
    scene.collection.objects.link(original)
    mod = original.modifiers.new("Distance detail","DECIMATE")
    mod.ratio = .34
    bpy.context.view_layer.update()
    deps = bpy.context.evaluated_depsgraph_get()
    result = bpy.data.meshes.new_from_object(original.evaluated_get(deps), depsgraph=deps)
    bpy.data.objects.remove(original,do_unlink=True)
    bpy.data.meshes.remove(mesh)
    return result


def add_backdrop():
    scene=bpy.context.scene
    key="Street | Tree-lined campus perimeter"
    if scene.collection.children.get(key):
        return scene.collection.children[key]
    group=bpy.data.collections.new(key)
    scene.collection.children.link(group)
    tree=crown_mesh(scene)
    # The pedestrian court ends before these rows. Keep the photographic building
    # front clear and give the road and campus beyond it a continuous horizon.
    positions=[(52,-43),(53,-33),(51,-24),(52,-15),(54,-5),(52,6),(53,18),(52,30),
               (65,-39),(64,-26),(62,-12),(65,2),(64,16),(64,32),
               (-48,-41),(-35,-44),(-23,-44),(-11,-46),(3,-46),(17,-44),(30,-46),(43,-44),
               (-52,-33),(-52,-20),(-52,-8),(-53,6),(-55,19),(-53,32)]
    for i,(x,y) in enumerate(positions):
        obj=bpy.data.objects.new("Perimeter tree %02d"%(i+1),tree)
        group.objects.link(obj)
        obj.location=(x+math.sin(i*1.68),y,.09)
        k=1.31+.27*math.sin(i*1.17)
        obj.scale=(k*1.25,k*1.15,k)
        obj.rotation_euler.z=(i*2.4)%math.tau
    stone=finish("Court background limestone","c6c2ad",.05,.76)
    shade=finish("Court background reveals","677169",.05,.78)
    glass=finish("Court background windows","566d72",.33,.43)
    turf=finish("Court background lawns","667c53",.0,.86)
    vertices, faces, face_mats=[],[],[]
    def box(x,y,z,w,d,h,slot):
        n=len(vertices)
        vertices.extend((x+a*w/2,y+b*d/2,z+c*h) for c in (0,1) for a,b in ((-1,-1),(1,-1),(1,1),(-1,1)))
        for face in ((3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)):
            faces.append(tuple(n+j for j in face))
            face_mats.append(slot)
    # Tree lawns with a low stone lip. Leave campus paths through the bands.
    for y,l in [(-34,26),(-8,22),(19,23),(42,16)]:
        box(54,y,.08,7.6,l,.12,0);box(54,y,.20,7.32,l-.26,.035,3)
    for x in (-37,-12,13,38):
        box(x,-45,.083,21,7.2,.10,0);box(x,-45,.183,20.8,7.0,.036,3)
    # These distant volumes establish depth only. Their proportions are inferred.
    for x,y,w,length,levels in [(79,-20,9,24,4),(84,8,12,22,5),(79,35,10,17,3),
                                  (-78,-13,10,26,4),(-72,18,11,22,4)]:
        toward=-1 if x>0 else 1
        facade=x+toward*w/2
        box(x,y,.1,w,length,levels*3.04+.5,0)
        for level in range(levels):
            z=.68+level*3.04
            box(facade+toward*.035,y,z,.11,length-.55,1.78,1)
            bays=round(length/2.45)
            for col in range(bays):
                cy=y-length/2+(col+.5)*length/bays
                box(facade+toward*.107,cy,z+.25,.07,length/bays-.34,1.25,2)
            box(facade+toward*.19,y,z+1.81,.55,length+.22,.13,0)
        box(x,y,levels*3.04+.59,w+.58,length+.65,.24,0)
    mesh=bpy.data.meshes.new("Outer lawns and campus blocks")
    mesh.from_pydata(vertices,[],faces)
    for mat in (stone,shade,glass,turf):mesh.materials.append(mat)
    mesh.polygons.foreach_set("material_index",face_mats)
    obj=bpy.data.objects.new("Peripheral paths and background façades",mesh)
    group.objects.link(obj)
    return group
