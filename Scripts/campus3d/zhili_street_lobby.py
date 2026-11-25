"""An original daylit display for the C loggia. Positions are in campus metres.

The C building and its ground-floor information service are actual locations.
The display, observational prints and bench are an environment-art interpretation.
"""

from math import cos, pi, sin
from pathlib import Path
import struct
import tempfile
import zlib

import blf
import bpy
import imbuf
import numpy as np

from zhili_street_signs import _Assembly, _materials


COLLECTION = "Street | C loggia exhibit"


def _rgb(value):
    return tuple(int(value[i:i+2], 16) for i in (0, 2, 4))


def _publication(path):
    """Draw a rights-clean architectural elevation, leaf plate and service print."""
    width, height = 1536, 600
    page = np.empty((height, width, 3), dtype=np.uint8)
    page[:] = _rgb("e8e1cd")
    dark, blue, leaf, rust = "294148", "325563", "56654d", "a3573e"
    captions = []

    def rect(x1,y1,x2,y2,c):
        page[y1:y2,x1:x2] = _rgb(c)

    def line(x0,y0,x1,y1,c,th=2):
        left, right = max(0,int(min(x0,x1)-th-1)), min(width,int(max(x0,x1)+th+2))
        top, bottom = max(0,int(min(y0,y1)-th-1)), min(height,int(max(y0,y1)+th+2))
        if left >= right or top >= bottom:
            return
        yy,xx = np.ogrid[top:bottom,left:right]
        dx,dy = x1-x0,y1-y0
        t = np.clip(((xx-x0)*dx+(yy-y0)*dy)/max(dx*dx+dy*dy, 1e-6),0,1)
        mix = np.clip(th/2+.5-np.sqrt((xx-x0-t*dx)**2+(yy-y0-t*dy)**2),0,1)[:,:,None]
        block = page[top:bottom,left:right]
        block[:] = block*(1-mix)+np.array(_rgb(c))*mix

    def pathline(coords,c,th=2):
        for a,b in zip(coords,coords[1:]):
            line(*a,*b,c,th)

    def title(x,y,txt,size,c=dark,bold=False):
        captions.append((x,y,txt,size,c,bold))

    # Left: elevation and perspective studies. Recesses sit beneath a solid white band.
    rect(0,0,612,600,"e6ddc7")
    rect(24,28,72,35,rust)
    title(25,76,"粤海建筑手记",38,dark,True)
    title(26,104,"YUEHAI   /   ARCHITECTURAL FIELD NOTES",16)
    rect(26,133,587,420,"cdccb7")
    # Profile of the stepped tower, receding slab bands and contained punched windows.
    levels = [(53,272,8), (83,240,8), (118,209,8), (153,178,8)]
    for left,top,cols in levels:
        right = left+238
        pathline([(left,top+29),(left,top),(right,top+11),(right+56,top-4),
                  (right+56,top+20),(right,top+38),(left,top+29)],blue,2)
        for j in range(cols):
            x = left+10+j*27
            y = top+8+(x-left)*.047
            pathline([(x,y+10),(x,y),(x+20,y+1),(x+20,y+11),(x,y+10)],blue,2)
        for j in range(4):
            x = right+8+j*11
            line(x,top+11-(x-right)*.26,x,top+22-(x-right)*.26,blue,1.6)
    pathline([(42,324),(407,329),(535,304),(535,321),(407,348),(42,342),(42,324)],dark,3)
    for x in (63,144,227,308,390):
        pathline([(x,343),(x,386),(x+6,386),(x+6,343)],blue,2)
    for i in range(14):
        x=245+i*7
        pathline([(x,374-i*2.8),(x+7,374-i*2.8),(x+7,371-i*2.8)],dark,2)
    line(43,387,548,387,blue)
    title(26,483,"致理楼",49,dark,True)
    title(26,523,"白色廊檐、连续窗带与架空的庭院。",22)
    line(26,547,587,547,blue)
    title(26,573,"C  ·  ENTRANCE COURT",15)

    # Center: a two-colour botanical field plate with branching compound leaves.
    rect(612,0,1032,600,"53634d")
    title(635,67,"荔园草木",42,"f1ead5",True)
    title(636,96,"A CAMPUS FIELD STUDY",16,"ded9c4")
    pathline([(690,470),(737,401),(771,331),(802,242),(826,151)],"d7c9a0",3)
    def leaflet(x,y,angle,length):
        ux, uy = cos(angle),sin(angle)
        def xy(t,side):
            offset=side * 0.19*length*sin(pi*t)
            return x+ux*t*length-uy*offset,y+uy*t*length+ux*offset
        outline = [xy(t/12,1) for t in range(13)] + [xy(t/12,-1) for t in range(12,-1,-1)]
        pathline(outline,"e6dabb",2)
        line(x,y,*xy(1,0),"cfccab",1.6)
        for k in range(2,8):
            for side in (-1,1):
                line(*xy(k/11,0),*xy((k+1.2)/11,side),"b5b495",1)
    for px,py,spread in [(729,411,96),(756,359,114),(780,302,88),(799,250,71),(813,209,49)]:
        leaflet(px,py,-2.46,spread*.86)
        leaflet(px+2,py-4,-.42,spread)
    title(636,514,"观察一片复叶",24,"f3ecd9",True)
    title(636,548,"叶轴  /  小叶  /  侧脉",16,"d5dbc4")
    # Right: an actual service name and building, without invented schedules or phone numbers.
    rect(1032,0,1536,600,"eae8dc")
    rect(1058,28,1107,35,blue)
    title(1058,72,"校园服务",29,blue,True)
    title(1058,98,"CAMPUS SERVICES",15,blue)
    rect(1058,130,1508,393,blue)
    title(1082,350,"C",203,"e7e8da",True)
    title(1290,208,"致理楼",33,"e7e8da",True)
    title(1291,244,"ZHILI",19,"cdd9d1")
    line(1290,268,1477,268,"a1b9b0")
    title(1290,327,"一楼",35,"e7e8da",True)
    title(1291,358,"GROUND FLOOR",15,"cdd9d1")
    title(1058,463,"信息服务大厅",42,blue,True)
    title(1059,500,"Information Service Hall",23,blue)
    line(1058,535,1509,535,blue)
    title(1058,569,"深圳大学   /   粤海校区",19,blue)

    noise = np.random.default_rng(5638).normal(0,1.35,(height,width,1))
    page = np.clip(page.astype(np.float32)+noise,0,255).astype(np.uint8)
    def chunk(tag,data):
        return struct.pack(">I",len(data))+tag+data+struct.pack(">I",zlib.crc32(tag+data))
    path = Path(path)
    scan = b"".join(b"\x00"+row.tobytes() for row in page)
    png = b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR",struct.pack(">IIBBBBB",width,height,8,2,0,0,0))+chunk(b"IDAT",zlib.compress(scan,5))+chunk(b"IEND",b"")
    path.write_bytes(png)
    buffer = imbuf.load(str(path))
    normals = ("C:/Windows/Fonts/msyh.ttc", "/System/Library/Fonts/PingFang.ttc", "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc")
    bolds = ("C:/Windows/Fonts/SourceHanSansSC-Medium.ttf", "C:/Windows/Fonts/msyhbd.ttc", "/System/Library/Fonts/PingFang.ttc", "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc")
    def font_id(paths):
        filename = next((p for p in paths if Path(p).is_file()), None)
        if not filename:
            raise RuntimeError("A CJK font is required to typeset the loggia display.")
        return blf.load(filename)
    fonts = (font_id(normals),font_id(bolds))
    for x,y,txt,size,color,bold in captions:
        font = fonts[bold]
        with blf.bind_imbuf(font,buffer):
            blf.position(font,x,height-y,0)
            blf.size(font,size)
            blf.color(font,*[v/255 for v in _rgb(color)],1)
            blf.draw_buffer(font,txt)
    imbuf.write(buffer,filepath=str(path))
    buffer.free()


def _finish(name,color,roughness,metallic=0.0,alpha=1.0,emission=0.0):
    mat=bpy.data.materials.get("Zhili exhibit / "+name)
    if mat:
        return mat
    mat=bpy.data.materials.new("Zhili exhibit / "+name)
    mat.use_nodes=True
    shader=next(n for n in mat.node_tree.nodes if n.type=="BSDF_PRINCIPLED")
    rgb=tuple(((c/255+.055)/1.055)**2.4 for c in _rgb(color))+(1.0,)
    mat.diffuse_color=(*rgb[:3],alpha)
    shader.inputs["Base Color"].default_value=rgb
    shader.inputs["Roughness"].default_value=roughness
    shader.inputs["Metallic"].default_value=metallic
    shader.inputs["Alpha"].default_value=alpha
    if alpha<1:
        mat.surface_render_method="BLENDED"
        mat.use_backface_culling=True
    if emission:
        shader.inputs["Emission Color"].default_value=rgb
        shader.inputs["Emission Strength"].default_value=emission
    return mat


def _publication_material():
    material=_finish("archival print","e7decb",.72,emission=.42)
    if material.get("artwork_packed"):
        return material
    with tempfile.TemporaryDirectory() as directory:
        path=Path(directory)/"campus_field_notes.png"
        _publication(path)
        image=bpy.data.images.load(str(path))
        image.name="Zhili / three original foyer prints"
        image.pack()
        image.filepath="//campus_field_notes.png"
    nodes=material.node_tree.nodes
    tex=nodes.new("ShaderNodeTexImage")
    tex.image=image
    shader=next(n for n in nodes if n.type=="BSDF_PRINCIPLED")
    for socket in ("Base Color","Emission Color"):
        material.node_tree.links.new(tex.outputs["Color"],shader.inputs[socket])
    material["artwork_packed"]=True
    return material


def _pane(collection,name,material,width,height,origin):
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata([(-width/2,0,0),(width/2,0,0),(width/2,0,height),(-width/2,0,height)],[],[(0,1,2,3)])
    mesh.materials.append(material)
    uv=mesh.uv_layers.new(name="UVMap")
    uv.data.foreach_set("uv",[0,0,1,0,1,1,0,1])
    obj=bpy.data.objects.new(name,mesh)
    obj.location=origin
    collection.objects.link(obj)


def add_lobby():
    """Mount a freestanding case against the western glass bay, clear of both doors."""
    existing=bpy.data.collections.get(COLLECTION)
    if existing:
        return existing
    materials=_materials()
    materials.update({
        "paper":_publication_material(), "lamp":_finish("opal light","ffe0a8",.43,emission=1.8),
        "glass":_finish("anti-reflective glazing","b0cccf",.16,.33,.075),
        "timber":_finish("oiled timber","865c41",.59),
        "timber light":_finish("oiled timber second cut","90694a",.62),
    })
    collection=bpy.data.collections.new(COLLECTION)
    bpy.context.scene.collection.children.link(collection)
    display_x=-7.10
    # The existing curtain wall's transoms project to y=6.785 at eye height.
    display_y=6.66
    fixture=_Assembly("C loggia | aluminium-framed display case",(display_x,display_y,0),collection,materials,None)
    w,h=3.37,1.34
    bottom=.98
    for x in (-1.30,1.30):
        fixture.rectangle(x,-.060,.135,.180,.150,.012,"alloy",.010)
        fixture.rectangle(x,.038,.145,.045,.051,.89,"steel",.003)
    fixture.rectangle(0,.068,bottom-.02,w-.09,.095,h+.035,"gasket",.020)
    fixture.rectangle(0,.029,bottom,w,.106,h,"alloy",.028)
    fixture.rectangle(0,-.001,bottom+.024,w-.048,.040,h-.048,"gasket",.013)
    for x in (-w/2+.020,w/2-.020):
        fixture.rectangle(x,-.010,bottom+.032,.024,.045,h-.064,"alloy")
    fixture.rectangle(0,-.031,bottom+h-.018,w-.055,.096,.038,"alloy",.008)
    fixture.rectangle(0,-.017,bottom+h-.041,w-.095,.027,.009,"lamp")
    for x in (-w/2+.051,w/2-.051):
        for z in (bottom+.054,bottom+h-.056):
            fixture.fastener(x,-.015,z,radius=.0105)
    fixture.finish()
    pw,ph=3.225,1.236
    _pane(collection,"C loggia | original campus field prints",materials["paper"],pw,ph,(display_x,display_y-.005,1.03))
    _pane(collection,"C loggia | low-reflection cover glass",materials["glass"],pw+.019,ph+.010,(display_x,display_y-.018,1.025))

    bench=_Assembly("C loggia | timber waiting seat",(-9.95,6.22,0),collection,materials,None)
    for x in (-.72,.72):
        bench.rectangle(x,-.255,.128,.11,.48,.021,"alloy",.008)
        for y in (-.205,.147):
            bench.rectangle(x,y,.146,.063,.066,.315,"steel",.008)
            bench.fastener(x,y-.002,.175,.010)
        bench.rectangle(x,-.235,.412,.071,.452,.036,"steel",.005)
        bench.rectangle(x,.183,.420,.048,.051,.408,"steel",.006)
    for i in range(5):
        bench.rectangle(0,-.263+i*.093,.447,2.06,.080,.045,"timber light" if i in (1,4) else "timber",.008)
    for i in range(3):
        z=.563+i*.086
        bench.rectangle(0,.195+i*.012,z,2.06,.043,.067,"timber" if i!=1 else "timber light",.010)
        for x in (-.72,.72):
            bench.fastener(x,.192+i*.012,z+.033,.006)
    bench.finish()
    return collection
