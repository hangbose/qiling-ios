"""Build original, stylized campus maquettes. Run in Blender background with -- OUTPUT_DIRECTORY.

The official SZU campus map supplies relative landmarks. Dimensions, facades and planting
are art direction, not survey measurements. Coordinates are in model units.
"""
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector

OUT = Path(sys.argv[sys.argv.index("--") + 1])
OUT.mkdir(parents=True, exist_ok=True)
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
    bpy.ops.wm.read_factory_settings(use_empty=True)
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

def bench(x,y):
    for dx in (-1.15,1.15):
        box("Seats","steel",x+dx,y,.12,.18,.85,.64)
        box("Seats","steel",x+dx,y+.42,.7,.14,.15,.96)
    for i in range(4):
        box("Seats","wood",x,y-.36+.23*i,.75,3.1,.18,.11)
    for i in range(2):
        box("Seats","wood",x,y+.45,1.12+.26*i,3.1,.12,.19)

def text(group,body,x,y,z,size):
    data=bpy.data.curves.new(body,'FONT'); data.body=body; data.size=size
    data.align_x='CENTER';data.extrude=.015;data.materials.append(materials["trim"])
    obj=bpy.data.objects.new(group+"-"+body,data);bpy.context.collection.objects.link(obj)
    obj.location=(x,y,z);obj.rotation_euler.x=math.pi/2
    bpy.context.view_layer.objects.active=obj;obj.select_set(True)
    bpy.ops.object.convert(target="MESH");obj.select_set(False)

def wing(group,x,y,w,d,floors):
    floor=2.55; bottom=3.15; height=bottom+floor*floors
    box(group,"pave",x,y,.14,w+2,d+1.8,.3)
    box(group,"recess",x,y+.5,.43,w*.77,d*.65,2.5)
    for sign in (-1,1):
        for i in range(round(w/4)+1):
            xx=x+(w-1)*(i/round(w/4)-.5)
            box(group,"stone",xx,y+sign*(d/2-.5),.43,.59,.66,2.72)
    box(group,"glass",x,y,bottom,w-.58,d-.64,height-bottom)
    for k in range(floors+1):
        z=bottom+k*floor
        box(group,"stone",x,y,z,w,d,.48)
        box(group,"trim",x,y,z+.47,w+.18,d+.18,.12)
    for sign in (-1,1):
        for i in range(round(w/2)+1):
            xx=x+(w-.38)*(i/round(w/2)-.5)
            box(group,"stone",xx,y+sign*(d/2-.03),bottom,.23,.58,height-bottom+.62)
            if i%3==0:
                box(group,"reflect",xx+.55,y+sign*(d/2-.25),bottom+.62,.46,.13,height-bottom-.72)
        for j in range(round(d/2)+1):
            yy=y+(d-.38)*(j/round(d/2)-.5)
            box(group,"stone",x+sign*(w/2-.03),yy,bottom,.58,.24,height-bottom+.62)
    box(group,"roof",x,y,height+.6,w-.52,d-.52,.12)
    for sign in (-1,1):
        box(group,"stone",x,y+sign*(d/2-.18),height+.61,w,.24,.48)
        box(group,"stone",x+sign*(w/2-.18),y,height+.61,.24,d,.48)
    box(group,"stone",x-w*.18,y,height+.73,min(5,w*.4),min(4,d*.45),1.55)
    box(group,"roof",x-w*.18,y,height+2.28,min(5.35,w*.43),min(4.4,d*.48),.18)
    for i in range(3):
        box(group,"steel",x+w*.16+i*.94,y,height+.75,.68,1.45,.55)
    box(group,"clay",x+w*.24,y-d/2-.31,height-3.3,3.4,.32,2.15)
    text(group,group,x+w*.24,y-d/2-.51,height-2.88,1.53)

def bridge(x,y,w,d,z):
    box("Gallery","stone",x,y,z,w,d,.33)
    for sign in (-1,1):
        yy=y+sign*d/2
        box("Gallery","reflect",x,yy,z+.33,w,.1,.88)
        box("Gallery","trim",x,yy,z+1.23,w,.2,.13)
        for i in range(int(w/2)+1):
            box("Gallery","steel",x-w/2+w*i/int(w/2),yy,z+.33,.12,.14,2.5)
    box("Gallery","trim",x,y,z+2.9,w+.3,d+.45,.28)

def finish(name):
    for (group,col),(verts,faces) in mesh_objects.items():
        mesh=bpy.data.meshes.new(group+"-"+col);mesh.from_pydata(verts,[],faces);mesh.update()
        ob=bpy.data.objects.new(mesh.name,mesh);bpy.context.collection.objects.link(ob);mesh.materials.append(materials[col])
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+".glb")),export_format="GLB",export_materials="EXPORT",
                              export_animations=False,export_cameras=False,export_lights=False)

def campus_block():
    start()
    outline=[(-54,-32),(-49,-38),(45,-38),(53,-30),(53,30),(46,37),(-46,37),(-54,29)]
    prism("Site","rim",outline,-3.2,2.4);prism("Site","base",outline,-.8,.8)
    prism("Site","lawn",[(x*.988,y*.985) for x,y in outline],0,.13)
    box("Walks","pave",-1,-13,.13,91,17,.08)
    box("Walks","pave",-15,6,.13,13,43,.08)
    box("Walks","pave",7,6,.13,32,22,.08)
    for i in range(-45,44,3):
        line("Walks","joint",i,-21,i,-5,.048,.213,.01)
    for j in range(-20,-4,3):
        line("Walks","joint",-45,j,43,j,.048,.213,.011)
    wing("L1",-11,17,39,10,6)
    wing("L2",26,10,11,34,7)
    wing("L3",18,-13,24,9,5)
    bridge(14.3,16,12.5,4,6.85);bridge(26,-6.9,6.3,3.8,7.65)
    for n in range(4):
        box("Entry","stone",9,-18.6-n*.42,.2,8.2,.5,max(.12,.6-n*.14))
    for x,y in [(-38,-28),(-29,-28),(-20,-28),(-10,-28),(0,-28),(11,-29),(22,-29),(39,-26),
                (-45,-15),(-46,-4),(-44,8),(-42,20),(-32,28),(-20,29),(-7,29),(7,29),(20,29),(36,26),
                (43,15),(43,5),(43,-7),(-28,3),(1,7),(5,4)]:
        tree(x,y,rng.uniform(.78,1.2))
    for x,y in [(-30,-8),(-3,-7),(4,10),(39,-13),(-35,14)]:
        box("Garden","stone",x,y,.14,8,2,.5);box("Garden","soil",x,y,.64,7.6,1.6,.09)
        for n in range(10):
            crown("Garden",rng.choice(["leaf","petal","petal"]),x-3.4+n*.75,y,.7,.64,.95)
    for x,y in [(-32,-10),(-19,-10),(-3,-9),(1,1),(9,1),(-27,10)]:
        bench(x,y)
    for x in [-35,-12,9,34]:
        prism("Lighting","steel",oval(x,-23,.13,.13,8),.13,3.7)
        box("Lighting","ink",x+.47,-23,3.8,1.15,.45,.15)
        box("Lighting","yellow",x+.72,-23,3.71,.55,.4,.09)
    # A row of stepping stones and seating along the tree-lined approach.
    for i in range(21):box("Walks","sand",-47+i*4.5,-24,.14,3.6,1.4,.075)
    finish("Zhili")

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

campus_block()
overview()
