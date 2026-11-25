"""Build original, stylized campus maquettes. Run in Blender background with -- OUTPUT_DIRECTORY.

The official SZU campus map supplies relative landmarks. Dimensions, facades and planting
are art direction, not survey measurements. Coordinates are in model units.
"""
import math
import random
import sys
from pathlib import Path

import bpy

OUT = None
palette = {
    "stone":"e5dfcc", "trim":"faf0d7", "sand":"c9ad87", "pave":"dfceb1", "joint":"c3ae92",
    "glass":"4d7176", "reflect":"92b7b0", "recess":"334c50", "steel":"6a7c73", "roof":"adc2b1",
    "lawn":"9db380", "lawn2":"819e78", "darkleaf":"497564", "leaf":"72996e", "tip":"a5b977",
    "bark":"816650", "wood":"b87b55", "clay":"bb755c", "petal":"d5808a", "yellow":"ebc37b",
    "soil":"9d846b", "base":"e8d6b6", "rim":"b69e80", "road":"a5a699", "pool":"83b5b0",
    "poolrim":"b4d0ba", "track":"c58e72", "chalk":"f0e8cb", "ink":"354c48",
}
mesh_objects = {}
materials = {}
rng = random.Random(90453)

def linear(v):
    n = int(v,16)/255
    return n/12.92 if n < .04045 else ((n+.055)/1.055)**2.4

def start():
    bpy.ops.wm.read_homefile(use_empty=True, use_factory_startup=True)
    # Keep default node names stable in batch builds on localized Blender installs.
    bpy.context.preferences.view.use_translate_new_dataname = False
    mesh_objects.clear()
    materials.clear()
    rng.seed(90453)
    for key, rgb in palette.items():
        m = bpy.data.materials.new(key)
        m.diffuse_color = (*[linear(rgb[i:i+2]) for i in (0,2,4)], 1)
        m.use_nodes = True
        shader = m.node_tree.nodes.get("Principled BSDF")
        shader.inputs["Base Color"].default_value = m.diffuse_color
        shader.inputs["Roughness"].default_value = .62 if key in {"glass","pool"} else .87
        materials[key] = m

def shape(group, color, verts, faces):
    cache = mesh_objects.setdefault((group,color), ([],[]))
    offset = len(cache[0])
    cache[0].extend(verts)
    cache[1].extend(tuple(i+offset for i in f) for f in faces)

def prism(group,color,poly,z,h):
    # The outer loop is counterclockwise when viewed from above.
    if sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(poly, poly[1:]+poly[:1])) < 0:
        poly = poly[::-1]
    n=len(poly)
    vertices=[(x,y,z+up) for up in (0,h) for x,y in poly]
    sides=[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    shape(group,color,vertices,[tuple(reversed(range(n))),tuple(range(n,2*n)),*sides])

def box(group,col,x,y,z,w,d,h):
    prism(group,col,[(x-w/2,y-d/2),(x+w/2,y-d/2),(x+w/2,y+d/2),(x-w/2,y+d/2)],z,h)

def oval(x,y,a,b,n=20):
    return [(x+a*math.cos(2*math.pi*i/n),y+b*math.sin(2*math.pi*i/n)) for i in range(n)]

def line(group,c,x1,y1,x2,y2,width,z,h):
    length=math.hypot(x2-x1,y2-y1)
    dx=(y2-y1)*width/(2*length); dy=(x1-x2)*width/(2*length)
    prism(group,c,[(x1+dx,y1+dy),(x2+dx,y2+dy),(x2-dx,y2-dy),(x1-dx,y1-dy)],z,h)

def crown(group,c,x,y,z,r,height):
    n=9
    verts=[(x,y,z)]
    for j,(rr,hh) in enumerate(((.78,.14),(1,.45),(.76,.78))):
        for i in range(n):
            a=2*math.pi*(i+j*.28)/n
            v=r*rr*rng.uniform(.89,1.10)
            verts.append((x+math.cos(a)*v,y+math.sin(a)*v,z+height*hh))
    verts.append((x+.08*r,y,z+height))
    top=len(verts)-1
    faces=[]
    for i in range(n):
        k=(i+1)%n
        faces.extend([(0,k+1,i+1),(1+2*n+i,1+2*n+k,top)])
        for j in (0,1):
            a=1+j*n
            faces.extend([(a+i,a+k,a+n+i),(a+k,a+n+k,a+n+i)])
    shape(group,c,verts,faces)

def tree(x,y,s=1):
    group="Garden"
    prism(group,"bark",oval(x,y,.28*s,.28*s,7),.15,3.2*s)
    crown(group,"darkleaf",x,y,2.4*s,2.42*s,3.8*s)
    crown(group,rng.choice(["leaf","leaf","tip"]),x-.5*s,y+.25*s,3.5*s,2*s,2.9*s)
    crown(group,"leaf",x+1.25*s,y-.4*s,2.85*s,1.5*s,2.6*s)

def finish(name, prepare_mesh=None):
    for (group,col),(verts,faces) in mesh_objects.items():
        mesh=bpy.data.meshes.new(group+"-"+col);mesh.from_pydata(verts,[],faces);mesh.update()
        ob=bpy.data.objects.new(mesh.name,mesh);bpy.context.collection.objects.link(ob);mesh.materials.append(materials[col])
    if prepare_mesh:
        prepare_mesh(OUT)
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+".glb")),export_format="GLB",export_materials="EXPORT",
                              export_vertex_color="ACTIVE" if prepare_mesh else "MATERIAL",
                              export_animations=False,export_cameras=False,export_lights=False)

def overview():
    start()
    # Relative positions follow the current illustrated campus map, in map-page orientation.
    outline=[(-52,45),(17,66),(28,51),(21,22),(47,17),(54,7),(46,-40),(24,-53),(-31,-67),(-49,-27),(-62,24)]
    prism("Campus","rim",outline,-3.4,2.5);prism("Campus","lawn",outline,-.9,1)
    for x,y,a,b in [(-18,-18,8,6),(-25,-30,3.8,7),(-37,22,2,2.8)]:
        prism("Lakes","poolrim",oval(x,y,a+.8,b+.8),.1,.05);prism("Lakes","pool",oval(x,y,a,b),.15,.08)
    roads=[[(-36,-55),(-31,-22),(-39,13),(-30,32),(1,49),(14,50)],
           [(-43,-14),(-11,-10),(11,-6),(40,-9)], [(-32,25),(-7,31),(14,27)],
           [(-26,-40),(-1,-30),(11,-6),(11,25),(6,40)],[(22,-46),(28,-19),(32,11)]]
    for route in roads:
        for p,q in zip(route,route[1:]):line("Roads","pave",*p,*q,1.9,.12,.08)
    line("Baishi","road",12,-55,24,20,3,.12,.14)
    line("Bridge","trim",13,-8,28,-8,1.8,.55,.3)
    for x,y,a,b in [(10,45,5,9),(-16,-11,5,7)]:
        prism("Sports","track",oval(x,y,a,b),.12,.2);prism("Sports","lawn2",oval(x,y,a*.8,b*.83),.32,.06)
    # Landmark groups plus subdued context massing; do not imply survey-level accuracy.
    groups=[(-30,30,4,2),(-30,19,3,2),(-18,36,4,1),(-9,15,2,1),(-2,24,3,1),(-10,0,3,2),
            (-24,-1,3,1),(2,6,2,2),(-17,-41,4,2),(-13,-53,3,2),(1,-36,2,2),
            (34,4,3,2),(29,-17,3,1),(31,-33,2,2)]
    for gx,gy,n,m in groups:
        for i in range(n):
            for j in range(m):
                x=gx+i*2.9;y=gy+j*4.2;h=rng.uniform(1.6,4.5)
                box("Buildings","stone",x,y,.22,2.3,3.3,h)
                box("Buildings","roof" if gy>-30 else "clay",x,y,h+.22,2.5,3.4,.23)
    for i in range(150):
        x,y=rng.uniform(-39,9),rng.uniform(-50,43)
        if any((x-a)**2/95+(y-b)**2/64<1 for a,b in [(-18,-18),(-25,-30),(10,45),(-16,-11)]):continue
        if any(gx-2<x<gx+nx*3+1 and gy-2<y<gy+ny*4.2 for gx,gy,nx,ny in groups):continue
        tree(x,y,rng.uniform(.30,.52))
    finish("Yuehai")

if __name__ == "__main__":
    OUT = Path(sys.argv[sys.argv.index("--") + 1])
    OUT.mkdir(parents=True, exist_ok=True)
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import zhili
    zhili.build(OUT)
    overview()
