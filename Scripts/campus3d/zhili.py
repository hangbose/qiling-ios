"""Photo-led exterior study of Zhili C. Local coordinates, estimated dimensions in metres.

Front: https://psy.szu.edu.cn/en/images/ba1d0f55f4c605d9ad5a93fcd850442.jpg
Courtyard and roof: SUIADR, project 46, photos 2021051077344 and 2021051064218.
The back, roof equipment and landscaping interpolate the visible elevations.
"""
import math
import random
from pathlib import Path
import bpy
from mathutils import Vector
import model as kit

box, prism, shape = kit.box, kit.prism, kit.shape
BAY = "C | Portico"
TOWER = "C | West elevation"
COURT = "L2 | Gallery"
GROUND = "Court | Paving"
GREEN = "Planting"
rng = random.Random(301)
palette = {
    "porcelain":"eeeae1","chalkwhite":"f7f3e9","reveal":"b3b8b5","soffit":"d0ccc0",
    "granite":"636969","granite2":"727876","ashlar":"a69f90","ashlar2":"aba698",
    "jointed":"8f9084","brass":"aa9774","frame":"303c3f","inkblack":"242c2e",
    "pane1":"41545a","pane2":"39494e","pane3":"4a5b60","pane4":"415157","lit":"817e6e",
    "paver1":"bdb9aa","paver2":"c6c0b1","paver3":"b7b5ab","kerb":"d6d0bc",
    "meadow":"7f9561","moss":"53713e","cypress":"345942","myrtle":"5f804d",
    "newleaf":"93ab68","laurel":"789153","leafshade":"46633e","loam":"736c54",
    "signblue":"246e8d","signline":"c7e0de","horizon":"9fadb0"
}
PANES=["pane1","pane1","pane2","pane3","pane4"]

def bar(group, material, a, b, width, depth=None):
    a,b=Vector(a),Vector(b)
    direction=(b-a).normalized()
    other=Vector((0,0,1)) if abs(direction.z)<.9 else Vector((0,1,0))
    side=direction.cross(other).normalized()*width/2
    up=direction.cross(side).normalized()*(depth or width)/2
    points=[tuple(center+s*side+t*up) for center in (a,b) for s,t in ((-1,-1),(1,-1),(1,1),(-1,1))]
    shape(group,material,points,[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])

def label(body, x, y, z, size, material, font=None):
    data=bpy.data.curves.new(body,"FONT")
    data.body=body;data.size=size;data.extrude=.012;data.bevel_depth=.003
    if font: data.font=font
    obj=bpy.data.objects.new("Lettering | "+body,data)
    bpy.context.collection.objects.link(obj);obj.location=(x,y,z);obj.rotation_euler.x=math.pi/2
    data.materials.append(kit.materials[material])
    bpy.context.view_layer.objects.active=obj;obj.select_set(True)
    bpy.ops.object.convert(target="MESH");obj.select_set(False)

def raised_floor(group,x,y,w,d,z):
    box(group,"soffit",x,y,z,w,d,.22)
    box(group,"porcelain",x,y,z+.22,w,d,.49)
    box(group,"chalkwhite",x,y,z+.71,w+.04,d+.04,.12)

def rectangle_panel(group,x,y,z,w,h,depth=.28,mat="porcelain"):
    box(group,mat,x,y,z,w,depth,h)

def punctuation_face(x, y, width, base, floors, story, patterns):
    # Lay actual masonry between recessed windows. Windows have returns and a sill.
    for level in range(floors):
        bottom=base+level*story
        windows=patterns[level%len(patterns)]
        rectangle_panel(TOWER,x,y,bottom,width,1.05)
        rectangle_panel(TOWER,x,y,bottom+2.32,width,story-2.32)
        last=x-width/2
        for center,w in windows:
            cx=x+center;left=cx-w/2
            if left>last: rectangle_panel(TOWER,(left+last)/2,y,bottom+1.05,left-last,1.27)
            box(TOWER,"frame",cx,y+.15,bottom+1.05,w,.13,1.27)
            count=max(1,round(w/1.02))
            for p in range(count):
                px=left+(p+.5)*w/count
                box(TOWER,rng.choice(PANES),px,y+.065,bottom+1.10,w/count-.07,.055,1.16)
            box(TOWER,"reveal",cx,y-.04,bottom+1.025,w+.07,.40,.043)
            last=cx+w/2
        end=x+width/2
        if end>last:rectangle_panel(TOWER,(end+last)/2,y,bottom+1.05,end-last,1.27)

def glass_grid(group,x,y,w,bottom,h,cols,rows):
    width,height=w/cols,h/rows
    box(group,"inkblack",x,y+.12,bottom,w,.19,h)
    rooms={}
    for c in range(cols):
        for r in range(rows):
            xx=x-w/2+(c+.5)*width
            room=(c//3,r//2)
            if room not in rooms:
                rooms[room]=rng.choices(["pane1","pane2","pane3","pane4","lit"],[24,28,13,29,6])[0]
            mat=rooms[room]
            box(group,mat,xx,y,bottom+r*height+.035,width-.073,.10,height-.073)
            if mat=="lit" and r%2==1:
                for k in range(3):
                    box(group,"reveal",xx,y-.059,bottom+(r+1)*height-.11*k-.1,width-.08,.032,.041)
        box(group,"frame",x-w/2+c*width,y-.08,bottom,.055,.095,h)
    for r in range(rows+1):box(group,"frame",x,y-.095,bottom+r*height,w,.12,.045)

def tower():
    x,y,w,d=6,9,16.6,21
    front=y-d/2; base=5.9; story=2.82; n=10; top=base+n*story
    box(TOWER,"granite",x,y+3,.17,w-1.9,d-6,base-.16)
    glass_grid(TOWER,x,front+4.1,w-1.5,.25,5.1,11,3)
    for dx in (-6.4,0,6.4):box(TOWER,"granite",x+dx,front+.8,.19,.78,.92,5.74)
    box(TOWER,"soffit",x,y,base,w,d,.22)
    patterns=[[(-6.4,1.5),(-3.4,1.0),(1.1,4.3),(6.1,1.45)],
              [(-6.1,2.25),(-1.55,1.15),(4.5,4.7)],
              [(-5.9,2.75),(-1.4,1.15),(3.65,3.8),(6.7,.70)]]
    punctuation_face(x,front,w,base,n,story,patterns)
    box(TOWER,"porcelain",x,y+d/2,base,w,.4,n*story)
    for side in (-1,1):
        xx=x+side*w/2
        box(TOWER,"pane2",xx-side*.36,y,base,.20,d,n*story)
        for floor in range(n+1):
            box(TOWER,"porcelain",xx,y,base+floor*story,.86,d,.46)
        for i in range(13):box(TOWER,"chalkwhite",xx,y-d/2+i*d/12,base,.72,.25,n*story+.5)
    # Two conspicuously hollow lantern bays, with a glazed wall set deeply behind.
    for z,h in [(top,2.25),(top+2.75,5.4)]:
        raised_floor(TOWER,x,y-1,w+1.5,d+2.5,z)
        for side in (-1,1):box(TOWER,"chalkwhite",x+side*(w+.7)/2,y-1,z+.83,.44,d+2.5,h)
        glass_grid(TOWER,x,front+2.6,w-.5,z+.85,h-.15,10,3)
    raised_floor(TOWER,x,y-1,w+1.5,d+2.5,top+8.55)
    for dx in (-7.7,0,7.7):bar(TOWER,"reveal",(x+dx,front-2.0,top+9.38),(x+dx+1.1,front+.7,top+10.27),.12)

def curved_wing(name,x0,y0,x1,y1,bow,floors,modules):
    dx,dy=x1-x0,y1-y0;length=math.hypot(dx,dy);nx,ny=-dy/length,dx/length
    def xy(t,depth):
        bend=bow*math.sin(math.pi*t)+depth
        return x0+t*dx+bend*nx,y0+t*dy+bend*ny
    def strip(mat,t,u,near,far,z,h):
        prism(name,mat,[xy(t,near),xy(u,near),xy(u,far),xy(t,far)],z,h)
    for i in range(modules):
        a,b=i/modules,(i+1)/modules
        strip("granite",a,b,.7,8.3,.3,4)
        for k in range(floors):
            z=4.3+2.68*k
            strip(rng.choice(PANES),a,b,.72,7.65,z,2.68)
            strip("porcelain",a,b,0,8.05,z,.42)
            strip("chalkwhite",a,b,-.10,.16,z+.40,.09)
            strip("porcelain",a,a+.14/modules,-.14,.94,z+.43,2.25)
            strip("chalkwhite",a,b,-.14,-.055,z+1.09,.105)
            strip("frame",a+.54/modules,a+.56/modules,.58,.76,z+.47,2.15)
        top=4.3+floors*2.68
        strip("reveal",a,b,0,8.05,top,.18)
        strip("porcelain",a,a+.12/modules,-.1,.37,top,1.73)
        strip("chalkwhite",a,b,-.09,.38,top+1.6,.25)
        strip("porcelain",a,b,7.68,8.02,4.3,top-4.15)
    for t,u in [(0,.15/modules),(1-.15/modules,1)]:
        strip("granite",t,u,.45,7.85,.30,top+.02)

def staircase(group,x0,y0,z0,x1,y1,z1,width,n):
    length=math.hypot(x1-x0,y1-y0);dx=(x1-x0)/length;dy=(y1-y0)/length
    sx,sy=-dy*width/2,dx*width/2
    def point(t,sign):
        return x0+(x1-x0)*t+sign*sx,y0+(y1-y0)*t+sign*sy
    for i in range(n):
        t,u=i/n,(i+1)/n;top=z0+(z1-z0)*u
        prism(group,"paver2",[point(t,-1),point(u,-1),point(u,1),point(t,1)],top-.28,.28)
    for sign in (-1,1):
        ax,ay=point(0,sign);bx,by=point(1,sign)
        bar(group,"porcelain",(ax,ay,z0+.09),(bx,by,z1+.09),.27,.94)
        bar(group,"granite",(ax,ay,z0+1),(bx,by,z1+1),.065)
        for j in range(8):
            t=j/7;xx,yy=point(t,sign)
            box(group,"frame",xx,yy,z0+(z1-z0)*t+.3,.054,.054,.69)

def entrance(font):
    # The low white architrave and distinct dark piers in the official C entrance photograph.
    x,y=-2,-10
    box(BAY,"soffit",x,y,5.49,43,8.4,.18)
    box(BAY,"porcelain",x,y,5.67,43,8.54,2.21)
    box(BAY,"reveal",x,y-4.12,7.88,43,.42,.085)
    for xx in [-22,-10,3,18]:
        for yy in [-13.5,-6.5]:
            box(BAY,"granite",xx,yy,.18,.91,.98,5.5)
            for k in range(1,5):box(BAY,"granite2",xx,yy,.20+k*1.08,.92,.989,.033)
    for xx in [-20,-8,5,16]:
        box(BAY,"soffit",xx,y,5.53,.31,8.0,.09)
    for j in range(1,9):
        box(BAY,"reveal",-23.5+j*4.78,y-4.276,6.43,.013,.012,1.4)
    label("致理楼 C",13.2,-14.288,6.82,.68,"inkblack",font)
    label("Z H I   L I   B U I L D I N G",13.25,-14.291,6.62,.115,"inkblack")
    staircase(BAY,-7,-4.5,.23,5.7,-4.5,3.02,2.55,19)
    staircase(BAY,5.7,-2.0,3.02,-7,-2.0,5.82,2.55,19)
    box(BAY,"porcelain",6.25,-3.25,2.76,1.3,5.05,.27)
    # Basalt panel studio on the left. Real joints and dimensional lettering.
    box("Studio","granite",-24,-1.5,.21,13.4,13.6,6.22)
    box("Studio","ashlar",-24,-1.5,6.43,15,15,6.3)
    for i in range(6):
        for j in range(3):
            box("Studio",rng.choice(["ashlar","ashlar2"]),-31.5+(i+.5)*2.5,-9.02,6.45+j*2.08,2.478,.13,2.06)
    label("STUDIO",-29.8,-8.335,3.8,2,"inkblack")
    box(BAY,"inkblack",-4.6,3.4,.14,11,1.3,5.82)
    glass_grid(BAY,-4.6,2.70,10.6,.25,4.9,7,2)
    box(BAY,"granite",11.2,1.5,.20,8.8,5.5,5.64)
    # Solid bridge end joining the C wing to the glass hall in the front view.
    box(COURT,"chalkwhite",16.35,3.8,7.7,4.95,7.6,7.45)
    box(COURT,"soffit",16.35,3.8,7.57,4.95,7.6,.13)
    # Glazed upper teaching hall floating over open piers.
    gx,gy=28,4
    for xx in [16.7,22.6,28.5,34.4,39.6]:
        for yy in [-3.5,9]:box(COURT,"granite",xx,yy,.20,.94,1.05,8.38)
    raised_floor(COURT,gx,gy,25.6,16.6,8.56)
    glass_grid(COURT,gx,-4.39,24.8,9.41,7.5,20,6)
    for sign in [-1,1]:box(COURT,"porcelain",gx+sign*12.62,gy,9.37,.4,16.6,7.7)
    raised_floor(COURT,gx,gy,25.6,16.6,16.95)
    raised_floor(COURT,27,-6.3,16,4.6,3.25)
    staircase(COURT,36.5,-18,.24,36.5,-7.2,3.95,7.5,25)
    # The freestanding blue college sign is geometry, including a simplified line ornament.
    box(BAY,"signblue",-1.8,-14.5,.24,4.02,.32,1.48)
    box(BAY,"signline",-1.8,-14.67,.34,3.82,.035,.025)
    label("深圳大学心理学院",-3.42,-14.68,1.09,.362,"chalkwhite",font)
    label("SCHOOL OF PSYCHOLOGY",-3.46,-14.68,.60,.193,"chalkwhite")

def leaf(cx,cy,cz,size,material,angle,pitch):
    # Folded leaf catches light differently on either side of its midrib.
    u=Vector((math.cos(angle),math.sin(angle),0))*size
    v=Vector((-math.sin(angle),math.cos(angle),0))*size*.43
    c=Vector((cx,cy,cz));base=c-u*.5;tip=c+u*.7+Vector((0,0,pitch*size))
    verts=[tuple(base),tuple(c+v),tuple(tip),tuple(c-v),tuple(c+Vector((0,0,size*.18)))]
    shape(GREEN,material,verts,[(0,1,4),(1,2,4),(2,3,4),(3,0,4)])

def hedge(x,y,w,d):
    box(GREEN,"kerb",x,y,.13,w+.28,d+.28,.19)
    box(GREEN,"loam",x,y,.32,w,d,.09)
    for i in range(int(w*d*6)):
        xx=x+rng.uniform(-w*.49,w*.49);yy=y+rng.uniform(-d*.49,d*.49)
        h=.36+.13*math.cos(xx*1.1)+rng.uniform(.06,.31)
        kit.crown(GREEN,"leafshade",xx,yy,.36,.27,h*.81)
        for j in range(20):
            a=rng.uniform(0,math.tau);rad=rng.uniform(0,.29)
            leaf(xx+rad*math.cos(a),yy+rad*math.sin(a),h+.33-rad*.55+rng.uniform(-.06,.06),
                 rng.uniform(.075,.16),rng.choice(["newleaf","laurel","myrtle","myrtle"]),a,rng.uniform(-.15,.65))

def tree(x,y,scale):
    s=scale
    bar(GREEN,"bark",(x,y,.2),(x+.12*s,y-.09*s,3.75*s),.39*s)
    for n in range(7):
        a=n*2.4+1.1
        bx=x+math.cos(a)*rng.uniform(1.3,2.8)*s;by=y+math.sin(a)*rng.uniform(1.3,2.8)*s
        bz=(4.1+.27*n)*s
        bar(GREEN,"bark",(x,y,2.5*s),(bx,by,bz),.12*s)
        for j in range(5):
            dx=bx+rng.uniform(-.9,.9)*s;dy=by+rng.uniform(-.9,.9)*s
            bar(GREEN,"bark",(bx,by,bz-.36*s),(dx,dy,bz+.43*s),.054*s)
            for arm in range(4):
                angle=arm*math.pi/2+rng.uniform(-.4,.4)
                ex=dx+math.cos(angle)*.69*s;ey=dy+math.sin(angle)*.69*s
                ez=bz+rng.uniform(.4,1.2)*s
                bar(GREEN,"bark",(dx,dy,bz+.29*s),(ex,ey,ez),.029*s)
                for _ in range(45):
                    az=rng.uniform(0,math.tau);dist=math.sqrt(rng.random())*.62*s
                    lx=ex+math.cos(az)*dist;ly=ey+math.sin(az)*dist
                    lz=ez+(.25-dist/s*.55+rng.uniform(-.18,.18))*s
                    leaf(lx,ly,lz,rng.uniform(.14,.29)*s,rng.choice(["myrtle","newleaf","laurel","leafshade"]),az,rng.uniform(-.9,.6))

def ground():
    outline=[(-46,-32),(-42,-36),(42,-36),(46,-32),(46,29),(42,33),(-42,33),(-46,29)]
    prism(GROUND,"sand",outline,-1.0,1.0)
    prism(GROUND,"paver1",outline,0,.12)
    # The rectangular grass panels and narrow paving joints anchor the portico.
    for x,y,w,d in [(-23,-22,22,9),(2,-22,19,10),(-32,1,9,10),(19,-17,7,4),(23,17,8,8)]:
        box(GROUND,"kerb",x,y,.12,w+.28,d+.28,.09)
        box(GROUND,"meadow",x,y,.21,w,d,.04)
        for i in range(int(w*d*4)):
            xx=x+rng.uniform(-w*.5,w*.5);yy=y+rng.uniform(-d*.5,d*.5)
            leaf(xx,yy,.252,.036,rng.choice(["laurel","meadow"]),rng.uniform(0,6.28),.63)
    for yy in (-29.5,-15.8,-11,-6):
        for i in range(60):
            xx=-41+i*1.38
            for j in range(3):box(GROUND,rng.choice(["paver1","paver2","paver3"]),xx+(j%2)*.69,yy+j*.55,.122,1.365,.537,.017)
    hedge(-22,-15.9,14.5,1.9);hedge(-38,7,3,13);hedge(22,14,9,2)
    for x,y,s in [(-38,-21,.95),(-42,-3,1.08),(-39,19,.87),(40,-23,1.05),(42,13,.95),(-3,26,.84)]:
        tree(x,y,s)
    for x in (-25,-12,0,13,25):
        box(GROUND,"frame",x,-23.3,.14,.28,.38,.15);box(GROUND,"brass",x,-23.3,.29,.18,.26,.03)

def build(folder, studio=False):
    kit.OUT=Path(folder);kit.OUT.mkdir(exist_ok=True,parents=True);kit.palette.update(palette);kit.start();rng.seed(301)
    for key in PANES+["frame"]:
        shader=kit.materials[key].node_tree.nodes.get("Principled BSDF")
        shader.inputs["Metallic"].default_value=.54 if key!="frame" else .35
        shader.inputs["Roughness"].default_value=.22 if key!="frame" else .43
    options=[Path("C:/Windows/Fonts/msyhbd.ttc"),Path("/System/Library/Fonts/PingFang.ttc"),Path("/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc")]
    font=next((bpy.data.fonts.load(str(p)) for p in options if p.exists()),None)
    if not font:raise RuntimeError("A Chinese outline font is required for the building lettering.")
    tower();curved_wing("L1 | Arc west",-43,15,-10,26,2.7,9,24)
    curved_wing("L2 | Arc east",15,24,43,18,1.55,10,22)
    entrance(font);ground()
    kit.finish("Zhili")
    if studio:
        import zhili_studio
        zhili_studio.prepare(Path(folder))
