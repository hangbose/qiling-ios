"""Realtime ground cover inside the five existing Zhili lawn kerbs (metres)."""

import math
from pathlib import Path
import random
import struct
import tempfile
import zlib

import bpy
import numpy as np


COLLECTION="Street | realtime cut lawn"
LAWNS=((-23,-22,22,9),(2,-22,19,10),(-32,1,9,10),(19,-17,7,4),(23,17,8,8))
GRADE=.257
TILE_METRES=2.4


def _grass_texture():
    name="Zhili turf / mown blades, 2.4 m"
    prior=bpy.data.images.get(name)
    if prior:
        return prior
    size=768
    rng=np.random.default_rng(90721)
    y,x=np.mgrid[0:size,0:size]*math.tau/size
    macro=np.sin(x+y*.0)*1.7+np.sin(2*x+3*y+.64)*2.1+np.cos(4*x-y)*1.4+np.sin(7*y+5*x)*1.1
    grain=rng.normal(0,2.15,(size,size))
    lawn=np.array((69,87,54))+(macro+grain)[:,:,None]*np.array((.9,1,.60))
    # Several translucent passes of tapered, bent fibres. Wrapping the stamp
    # coordinates makes all four boundaries genuinely tileable.
    for count,base,opacity in ((12500,(52,69,46),.77),(15000,(75,96,58),.78),
                               (15000,(90,106,64),.76),(11000,(78,103,60),.79)):
        px,py=rng.uniform(0,size,(2,count))
        patch=np.sin(math.tau*px/size)*np.cos(2*math.tau*py/size)
        direction=-.72+1.25*patch+rng.normal(0,.91,count)
        cx,cy=np.cos(direction),np.sin(direction)
        length=rng.uniform(3.4,12.4,count)
        turn=rng.uniform(-.28,.28,count)*length
        warmth=rng.normal(0,1,count)
        tone=(np.asarray(base)+warmth[:,None]*np.array([4.5,2,1.5])
              +rng.normal(0,5,(count,1))+patch[:,None]*np.array([2.8,3,1.6]))
        # A modest minority of dried cut tips gives mown turf its muted straw colour.
        cut=rng.random(count)<.036
        tone[cut]+=np.array([17,10,3])
        for j in range(12):
            t=j/11
            bend=turn*t*t
            xx=px+t*length*cx-cy*bend
            yy=py+t*length*cy+cx*bend
            ix,iy=np.floor(xx).astype(int),np.floor(yy).astype(int)
            fx,fy=xx-ix,yy-iy
            color=tone+(t*.85-.58)*np.array([10,10,6])
            for dx,dy,fraction in [(0,0,(1-fx)*(1-fy)),(1,0,fx*(1-fy)),
                                   (0,1,(1-fx)*fy),(1,1,fx*fy)]:
                sx,sy=(ix+dx)%size,(iy+dy)%size
                strength=np.clip(fraction*opacity*(1.45-.60*t),0,.92)[:,None]
                lawn[sy,sx]=lawn[sy,sx]*(1-strength)+color*strength
    tile=np.clip(lawn,0,255).astype("u1")
    def chunk(tag,body):
        return struct.pack(">I",len(body))+tag+body+struct.pack(">I",zlib.crc32(tag+body))
    data=b"".join(b"\0"+row.tobytes() for row in tile)
    png=(b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR",struct.pack(">IIBBBBB",size,size,8,2,0,0,0))+
         chunk(b"IDAT",zlib.compress(data,7))+chunk(b"IEND",b""))
    with tempfile.TemporaryDirectory() as folder:
        path=Path(folder)/"mown_turf.png"
        path.write_bytes(png)
        image=bpy.data.images.load(str(path))
        image.name=name
        image.pack()
        image.filepath="//mown_turf.png"
    return image


def _material(name,blades=False):
    name="Street turf / "+name
    old=bpy.data.materials.get(name)
    if old:
        return old
    mat=bpy.data.materials.new(name)
    mat.use_nodes=True
    mat.use_backface_culling=not blades
    mat.diffuse_color=(.080,.12,.055,1)
    shader=next(n for n in mat.node_tree.nodes if n.type=="BSDF_PRINCIPLED")
    shader.inputs["Roughness"].default_value=.91 if not blades else .81
    shader.inputs["Specular IOR Level"].default_value=.19
    if blades:
        source=mat.node_tree.nodes.new("ShaderNodeVertexColor")
        source.layer_name="Blade pigmentation"
    else:
        source=mat.node_tree.nodes.new("ShaderNodeTexImage")
        source.image=_grass_texture()
        source.extension="REPEAT"
    mat.node_tree.links.new(source.outputs["Color"],shader.inputs["Base Color"])
    return mat


def _surface(collection):
    verts=[]; faces=[]; tex=[]
    for i,(cx,cy,w,d) in enumerate(LAWNS):
        # Each centimetre of kerb remains exposed. A 7 mm skirt meets the
        # original turf slab so the short edge cannot cast a floating shadow.
        ax,bx=cx-w/2+.008,cx+w/2-.008
        ay,by=cy-d/2+.008,cy+d/2-.008
        n=len(verts)
        verts.extend((x,y,z) for z in (GRADE,.249) for x,y in ((ax,ay),(bx,ay),(bx,by),(ax,by)))
        angle=[.18,1.08,.64,-.39,2.19][i]
        c,s=math.cos(angle),math.sin(angle)
        for x,y,z in verts[n:]:
            tex.append(((x*c-y*s)/TILE_METRES,(x*s+y*c)/TILE_METRES+(GRADE-z)/TILE_METRES))
        faces.append((n,n+1,n+2,n+3))
        for a in range(4):
            b=(a+1)%4
            faces.append((n+4+a,n+4+b,n+b,n+a))
    mesh=bpy.data.meshes.new("Five beds / metric turf UV")
    mesh.from_pydata(verts,[],faces)
    mesh.materials.append(_material("mown surface"))
    uv=mesh.uv_layers.new(name="2.4 metre turf repeat")
    uv.data.foreach_set("uv",[v for face in faces for i in face for v in tex[i]])
    mesh.update()
    collection.objects.link(bpy.data.objects.new("Courtyard | five mown turf surfaces",mesh))


def _tufts(collection):
    rng=random.Random(71821)
    verts=[]; faces=[]; colors=[]
    def grow(x,y,cx,cy,w,d):
        scale=rng.uniform(.70,1.16)
        phase=rng.uniform(0,math.tau)
        root_tint=rng.uniform(-6,5)
        for b in range(rng.randrange(3,7)):
            a=phase+b*2.399+rng.uniform(-.42,.42)
            cs,sn=math.cos(a),math.sin(a)
            lean=rng.uniform(.015,.061)*scale
            radius=rng.uniform(.002,.013)
            xx,yy=x+radius*cs,y+radius*sn
            ex,ey=xx+lean*cs,yy+lean*sn
            # No blade tips creep onto the adjacent stone or bicycle lane.
            if abs(ex-cx)>=w/2-.013 or abs(ey-cy)>=d/2-.013:
                continue
            h=rng.uniform(.027,.065)*scale
            spread=rng.uniform(.0025,.0053)*scale
            turn=rng.uniform(-.007,.007)
            shx,shy=xx+.40*lean*cs,yy+.40*lean*sn
            i=len(verts)
            verts.extend([(xx-spread*sn,yy+spread*cs,GRADE-.001),
                          (xx+spread*sn,yy-spread*cs,GRADE-.001),
                          (shx+spread*.70*sn,shy-spread*.70*cs,GRADE+h*.67),
                          (shx-spread*.70*sn,shy+spread*.70*cs,GRADE+h*.67),
                          (ex-turn*sn,ey+turn*cs,GRADE+h)])
            faces.extend([(i,i+1,i+2),(i,i+2,i+3),(i+3,i+2,i+4)])
            warm=rng.uniform(-.5,1.25)
            dry=rng.random()<.065
            tone=np.array([78+8*warm,99+4*warm,61-4*warm])+root_tint+(np.array([17,9,4]) if dry else 0)
            for gain in (.64,.68,.96,1.0,1.10):
                colors.append((*np.clip(tone*gain/255,0,1),1.0))
    for i,(cx,cy,w,d) in enumerate(LAWNS):
        for edge,span in enumerate((w,d,w,d)):
            # Broken irregular clusters within the kerb look better than a
            # continuous picket fence of grass along every lawn border.
            dense=5.7 if i<2 else 3.7
            for _ in range(round(span*dense)):
                along=rng.uniform(-.5,.5)*span
                inset=.04+abs(rng.gauss(.052,.085))
                if edge==0: x,y=cx+along,cy-d/2+inset
                elif edge==1: x,y=cx+w/2-inset,cy+along
                elif edge==2: x,y=cx+along,cy+d/2-inset
                else: x,y=cx-w/2+inset,cy+along
                grow(x,y,cx,cy,w,d)
        for _ in range(round(w*d*(.53 if i<2 else .32))):
            grow(cx+rng.uniform(-.48,.48)*w,cy+rng.uniform(-.48,.48)*d,cx,cy,w,d)
    mesh=bpy.data.meshes.new("Short turf / curved solid blades")
    mesh.from_pydata(verts,[],faces)
    mesh.materials.append(_material("root to tip",True))
    color=mesh.color_attributes.new(name="Blade pigmentation",type="BYTE_COLOR",domain="POINT")
    color.data.foreach_set("color_srgb",np.asarray(colors,dtype=np.float32).ravel())
    mesh.polygons.foreach_set("use_smooth",np.ones(len(faces),dtype=bool))
    mesh.update()
    collection.objects.link(bpy.data.objects.new("Courtyard | field and edge tufts",mesh))


def add_turf():
    """Add game-ready materials and meshes; studio stills keep their detailed sod."""
    scene=bpy.context.scene
    previous=scene.collection.children.get(COLLECTION)
    if previous:
        return previous
    collection=bpy.data.collections.new(COLLECTION)
    scene.collection.children.link(collection)
    try:
        _surface(collection)
        _tufts(collection)
        collection.hide_render=scene.collection.children.get("Courtyard | lawn cover") is not None
        return collection
    except Exception:
        for obj in list(collection.objects):
            mesh=obj.data
            bpy.data.objects.remove(obj,do_unlink=True)
            if mesh.users==0:
                bpy.data.meshes.remove(mesh)
        bpy.data.collections.remove(collection)
        raise
