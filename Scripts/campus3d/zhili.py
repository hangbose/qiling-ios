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
    "signblue":"548a9d","signline":"b7d4d7","crestblue":"37748f","signshadow":"2d627b",
    "signbase":"708083","ceilingjoint":"838477","horizon":"9fadb0",
    "stairrose":"ae806b","stairrose2":"b98870","stairnosing":"d1a28c","railsteel":"a8b2b2",
    "fixture":"e3e2cc","interior":"686b66","ceiling":"b8b6a8"
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
    data.resolution_u=4;data.bevel_resolution=0
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
    x,y,w,d=2.0,9,16.6,21
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
    # The long window bands climb to the near (east) corner in the entrance view.
    angle=math.radians(-24)
    ca,sa=math.cos(angle),math.sin(angle)
    for (group,_),(vertices,_) in kit.mesh_objects.items():
        if group==TOWER:
            vertices[:]=[(x+(xx-x)*ca-(yy-front)*sa,front+(xx-x)*sa+(yy-front)*ca,zz)
                         for xx,yy,zz in vertices]

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
    land=1.08/length; runs=[n//3,n//3,n-2*(n//3)]
    advance=(1-2*land)/n;rise=(z1-z0)/n
    t,z=0,z0
    for index,count in enumerate(runs):
        end=t+count*advance;endz=z+count*rise
        for i in range(count):
            a,b=t+i*advance,t+(i+1)*advance;top=z+(i+1)*rise
            prism(group,rng.choice(["stairrose","stairrose2"]),
                  [point(a,-1),point(b,-1),point(b,1),point(a,1)],top-.39,.39)
            prism(group,"stairnosing",[point(a,-1),point(a+.0015,-1),
                                      point(a+.0015,1),point(a,1)],top-.052,.056)
        for lateral in (-1,-.36,.34,1):
            a=point(t,lateral);b=point(end,lateral)
            if abs(lateral)==1:
                bar(group,"porcelain",(*a,z+.25),(*b,endz+.25),.30,1.3)
                if index<2:
                    c=point(end+land,lateral)
                    bar(group,"porcelain",(*b,endz+.25),(*c,endz+.25),.30,1.3)
            else:
                bar(group,"railsteel",(*a,z+.96),(*b,endz+.96),.059)
                for j in range(5):
                    f=j/4;xx,yy=point(t+(end-t)*f,lateral)
                    box(group,"railsteel",xx,yy,z+(endz-z)*f,.05,.05,.97)
        if index<2:
            u=end+land
            prism(group,"stairrose",[point(end,-1),point(u,-1),point(u,1),point(end,1)],endz-.39,.39)
        t,z=end+land,endz

def switchback():
    # The landing is behind the right-hand pier. Both flights have opaque cheeks.
    def flight(x0, x1, y, z0, z1):
        run=x1-x0; n=24
        for i in range(n):
            t=(i+1)/n
            box(BAY,"paver2",x0+run*(i+.5)/n,y,z0+(z1-z0)*t-.21,
                abs(run)/n+.012,2.8,.21)
        for yy in (y-1.43,y+1.43):
            # Vertical faces and a level upper cap at both landings.
            for a,b in ((0,.46),(.46,.48),(.48,1)):
                xa,xb=x0+a*run,x0+b*run
                za,zb=z0+(z1-z0)*a,z0+(z1-z0)*b
                vertices=[(xx,yy+dy,zz+dz) for dy in (-.11,.11)
                          for xx,zz,dz in [(xa,za,-.2),(xb,zb,-.2),(xb,zb,1.09),(xa,za,1.09)]]
                if run<0:
                    vertices=vertices[4:]+vertices[:4]
                shape(BAY,"porcelain",vertices,[(0,1,2,3),(7,6,5,4),(4,5,1,0),(1,5,6,2),(2,6,7,3),(3,7,4,0)])
            bar(BAY,"granite2",(x0,yy,z0+1.16),(x1,yy,z1+1.16),.06)
    flight(-2.85,6.0,-5.7,.23,3.74)
    flight(6.0,-4.2,-2.65,3.74,7.23)
    box(BAY,"porcelain",6.67,-4.17,3.43,1.36,5.95,.31)
    box(BAY,"porcelain",7.26,-4.17,3.74,.16,5.95,1.07)
    box(BAY,"soffit",-8,-2.65,6.95,7.6,3.02,.29)
    box(BAY,"porcelain",-8,-4.09,7.17,7.6,.24,1.15)

def stone_studio():
    # Oblique, floating limestone volume with two exposed panelled faces.
    # The projecting corner, soffit and recessed support are all visible above the architrave.
    group="Studio"
    near=(-17.9,-13.9); far=(-12.0,16.8); width=13.4
    def xy(t,u):
        return (near[0]+(far[0]-near[0])*t-u,near[1]+(far[1]-near[1])*t+.28*u)
    low,high=12.45,21.75
    prism(group,"ashlar",[xy(0,0),xy(1,0),xy(1,width),xy(0,width)],low,high-low)
    prism(group,"soffit",[xy(0,0),xy(1,0),xy(1,width),xy(0,width)],low-.13,.13)
    for row in range(5):
        z=low+row*(high-low)/5
        for i in range(13):
            t0,t1=(i+.008)/13,(i+.992)/13
            prism(group,rng.choice(["ashlar","ashlar","ashlar2"]),
                  [xy(t0,-.052),xy(t1,-.052),xy(t1,.04),xy(t0,.04)],z+.012,(high-low)/5-.026)
        for i in range(6):
            u0,u1=width*(i+.008)/6,width*(i+.992)/6
            prism(group,rng.choice(["ashlar","ashlar2"]),
                  [xy(-.002,u0),xy(.003,u0),xy(.003,u1),xy(-.002,u1)],z+.012,(high-low)/5-.026)
    prism(group,"granite",[xy(.13,1.9),xy(.91,1.9),xy(.91,width-1),xy(.13,width-1)],.18,low-.18)
    glass_grid(group,-23.3,-9.8,9.4,.28,6.32,6,3)

def school_sign(font):
    x,y=-1.05,-14.72
    left=x-2.03; face=y-.14
    box(BAY,"signbase",x,y,.18,4.23,.47,.23)
    box(BAY,"signblue",x,y,.4,4.06,.27,1.27)
    def stroke(ax,az,bx,bz,width=.022,mat="signshadow"):
        bar(BAY,mat,(left+ax,face-.018,az),(left+bx,face-.018,bz),width,.016)
    # Foil-cut botanical tracery in the sign's lower panel and the inset shield at right.
    for row in range(3):
        for col in range(10):
            cx=.13+col*.325+(.10 if row%2 else 0); cz=.72+.29*row
            for j in range(7):
                a=j*math.tau/7+.25*(col%3)
                dx,dz=math.cos(a)*.11,math.sin(a)*.115
                stroke(cx+.28*dx,cz+.28*dz,cx+dx,cz+dz,.018)
    for inset in (0,.105,.20):
        contour=[(3.27+inset,1.54),(3.27+inset,.67+inset/2),(3.62,.48+inset),
                 (3.96-inset,.67+inset/2),(3.96-inset,1.54)]
        for a,b in zip(contour,contour[1:]):stroke(*a,*b,.047)
    cx,cz=.52,1.81
    for rad,mat in ((.405,"crestblue"),(.349,"signline"),(.31,"crestblue")):
        verts=[(left+cx+rad*math.cos(a*math.tau/36),face-.046-(.405-rad)*.32,
                cz+rad*math.sin(a*math.tau/36)) for a in range(36)]
        shape(BAY,mat,verts,[tuple(range(36))])
    for ax,az,bx,bz in ((.39,2.02,.39,1.73),(.39,1.73,.52,1.63),(.52,1.63,.65,1.73),
                        (.65,1.73,.65,2.02),(.39,2.02,.65,2.02)):
        bar(BAY,"chalkwhite",(left+ax,face-.09,az),(left+bx,face-.09,bz),.036,.018)
    label("深圳大学心理学院",left+.91,face-.046,1.67,.487,"chalkwhite",font)
    label("School of Psychology Shenzhen University",left+.94,face-.047,1.52,.174,"chalkwhite")
    label("SCHOOL OF PSYCHOLOGY",left+.14,face-.051,.51,.239,"chalkwhite")

def hall_return(gx,gy,bottom,side):
    # Two rows of individually punched voids with a deep reveal in white render.
    xx=gx+side*9.50; start,end=gy-8.30,gy+8.30
    rows=(((-6.5,.46),(-4.0,1.44),(-1.1,1.28),(1.0,.56),(3.5,1.31),(6.35,.80)),
          ((-5.45,1.55),(-2.8,.50),(-.55,1.18),(2.15,1.24),(4.83,.49),(6.75,.89)))
    story=5.20
    for level, openings in enumerate(rows):
        z=bottom+level*story
        box(COURT,"porcelain",xx,gy,z,.46,16.6,1.45)
        box(COURT,"porcelain",xx,gy,z+3.45,.46,16.6,story-3.45)
        edge=start
        for off,w in openings:
            mid=gy+off;a,b=mid-w/2,mid+w/2
            box(COURT,"porcelain",xx,(a+edge)/2,z+1.45,.46,a-edge,2)
            box(COURT,"frame",xx-side*.19,mid,z+1.45,.10,w,2)
            box(COURT,rng.choice(PANES),xx-side*.12,mid,z+1.50,.035,w-.095,1.90)
            box(COURT,"frame",xx-side*.065,mid,z+2.71,.052,w,.042)
            if w>1:
                box(COURT,"frame",xx-side*.065,mid+.12,z+1.46,.06,.046,1.96)
            box(COURT,"reveal",xx+side*.04,mid,z+1.42,.56,w+.06,.043)
            edge=b
        box(COURT,"porcelain",xx,(edge+end)/2,z+1.45,.46,end-edge,2)

def curtain_hall(gx,gy):
    bottom=14.05;front=gy-8.37;span=18.58;height=10.4
    raised_floor(COURT,gx,gy,19.48,16.6,bottom-.83)
    for side in (-1,1):
        hall_return(gx,gy,bottom,side)
    raised_floor(COURT,gx,gy,19.48,16.6,bottom+height)
    # The curtain wall has a separate transom/mullion grid and usable room depth behind it.
    # Opaque spandrels conceal each floor edge; some offices have lowered venetian blinds.
    bay=span/17;row=height/8
    for i in range(17):
        xx=gx-span/2+(i+.5)*bay
        for j in range(8):
            mat=PANES[((i//3)*2+(j//4)+int(j%4==0))%len(PANES)]
            box(COURT,mat,xx,front,bottom+j*row+.025,bay-.048,.032,row-.052)
            if j%4==0:
                box(COURT,"frame",xx,front+.19,bottom+j*row+.03,bay-.05,.09,.42)
        if i in (1,2,7,8,9,14):
            for j in range(11 if i<7 else 7):
                box(COURT,"ceiling",xx,front+.34,bottom+height-.34-j*.092,bay-.10,.14,.030)
    for i in range(18):
        xx=gx-span/2+i*bay
        box(COURT,"frame",xx,front+.045,bottom,.075,.24,height)
        box(COURT,"inkblack",xx,front-.086,bottom,.054,.039,height)
    for j in range(9):
        box(COURT,"frame",gx,front+.024,bottom+j*row-.024,span,.20,.067)
    for level in (0,1):
        z=bottom+level*height/2
        box(COURT,"ceiling",gx,gy,z,18.61,16.08,.24)
        box(COURT,"interior",gx,gy+7.8,z,18.6,.27,height/2)
        for off in (-6,-1,5.1):
            box(COURT,"ceiling",gx+off,gy+2.08,z,.15,11.5,height/2)
        for off in (-7.1,-2.2,3.4,7.3):
            box(COURT,"fixture",gx+off,front+2.4,z+height/2-.18,1.42,.12,.04)
    for xx in (gx-8.95,gx-3.0,gx+3.0,gx+8.5):
        for yy in (-7.35,1.0,7.8):
            box(COURT,"granite",xx,yy,.20,1.04,1.15,bottom-1.01)
        box(COURT,"soffit",xx,gy,bottom-1.19,.62,16.12,.38)
    for yy in (-7.35,-3.22,1,4.61,7.8):
        box(COURT,"soffit",gx,yy,bottom-1.15,18.9,.54,.35)

def loggia_details():
    for xx in (-16.50,-3.95,8.94,14.3):
        for yy in (-11.65,-7.07):
            box(BAY,"frame",xx,yy,7.428,.16,1.55,.050)
            box(BAY,"fixture",xx,yy,7.422,.097,1.44,.018)
    for mid in (-13.0,11.6):
        y=6.75
        for side in (-1,1):
            xx=mid+side*.565
            box(BAY,"pane3",xx,y,.27,1.075,.035,2.50)
            for edge in (-.55,.55):
                box(BAY,"frame",xx+edge,y-.020,.23,.044,.11,2.56)
            box(BAY,"frame",xx,y-.03,2.72,1.11,.12,.070)
            grip=mid+side*.125
            bar(BAY,"railsteel",(grip,y-.16,1.01),(grip,y-.16,1.70),.04)
            for h in (1.04,1.67):
                bar(BAY,"railsteel",(grip,y-.16,h),(grip,y-.01,h),.035)

def entrance(font):
    x,y=-3.02,-9.99
    width=42.98
    box(BAY,"soffit",x,y,7.48,width,8.54,.22)
    box(BAY,"porcelain",x,y,7.70,width,8.54,2.91)
    box(BAY,"reveal",x,-14.18,10.61,width,.20,.063)
    for xx in (-21,-8.15,4.85,17.85):
        for yy in (-13.79,-4.0):
            box(BAY,"granite",xx,yy,.18,1.04,1.09,7.31)
            for k in range(1,5):
                box(BAY,"granite2",xx,yy,.21+k*1.42,1.049,1.10,.016)
    for xx in (-21,-8.15,4.85,17.85):
        box(BAY,"ceilingjoint",xx,y,7.454,.052,8.42,.027)
        box(BAY,"soffit",xx+.11,y,7.437,.16,8.42,.046)
    for yy in (-12.18,-9.25,-6.4):
        box(BAY,"ceilingjoint",x,yy,7.469,width,.024,.012)
    for j in range(1,9):
        box(BAY,"reveal",-24.51+j*4.78,-14.267,7.72,.014,.018,2.89)
    box(BAY,"reveal",x,-14.269,8.94,width,.017,.010)
    label("致理楼 C",13.25,-14.29,8.96,.72,"inkblack",font)
    label("Z H I   L I   B U I L D I N G",13.29,-14.292,8.73,.118,"inkblack")
    # The open loggia ends in shaded glass doors, with lateral circulation behind the piers.
    box(BAY,"inkblack",0,7.7,.14,39,1.4,7.48)
    for cx,ww in ((-13.8,7.8),(-4.5,9.2),(10.5,12.0)):
        glass_grid(BAY,cx,6.94,ww,.22,5.82,max(5,round(ww/1.28)),3)
    box(BAY,"soffit",-.5,1.12,7.25,40.7,13.96,.38)
    for xx in (-17.2,-3.85,4.25,12.3):
        box(BAY,"inkblack",xx,-2.0,.16,.76,.9,7.1)
    loggia_details()
    switchback()
    stone_studio()
    # Bridge projecting diagonally from the tower to the tall glazed eastern hall.
    corners=[(13.40,-3.5),(23.70,-8.12),(24.67,-5.95),(14.36,-1.32)]
    prism(COURT,"soffit",corners,12.41,.21)
    prism(COURT,"chalkwhite",corners,12.62,7.38)
    gx,gy=33.35,.4
    curtain_hall(gx,gy)
    raised_floor(COURT,28,-5.7,19.2,5.8,5.78)
    staircase(COURT,36.5,-20.7,.24,36.5,-5.28,6.53,11.7,37)
    school_sign(font)

def leaf(cx,cy,cz,size,material,angle,pitch,group=GREEN):
    # Folded leaf catches light differently on either side of its midrib.
    u=Vector((math.cos(angle),math.sin(angle),0))*size
    v=Vector((-math.sin(angle),math.cos(angle),0))*size*.43
    c=Vector((cx,cy,cz));base=c-u*.5;tip=c+u*.7+Vector((0,0,pitch*size))
    verts=[tuple(base),tuple(c+v*.70),tuple(tip),tuple(c-v*.64),tuple(c+Vector((0,0,size*.075)))]
    shape(group,material,verts,[(0,1,4),(1,2,4),(2,3,4),(3,0,4)])

def hedge(x,y,w,d):
    box(GREEN,"kerb",x,y,.13,w+.28,d+.28,.19)
    box(GREEN,"loam",x,y,.32,w,d,.09)
    for i in range(int(w*d*6)):
        xx=x+rng.uniform(-w*.49,w*.49);yy=y+rng.uniform(-d*.49,d*.49)
        h=.36+.13*math.cos(xx*1.1)+rng.uniform(.06,.31)
        for j in range(24):
            a=rng.uniform(0,math.tau);rad=rng.uniform(0,.29)
            top=h+.33-rad*.55+rng.uniform(-.10,.08)
            for k in range(2):
                leaf(xx+rad*math.cos(a),yy+rad*math.sin(a),top-.22*k,
                     rng.uniform(.09,.17)*(1+.5*k),
                     rng.choice(["laurel","myrtle","leafshade"]) if k else rng.choice(["newleaf","laurel","myrtle"]),
                     a+k,rng.uniform(-.55,.85))

def tree(x,y,scale):
    from zhili_garden import shade_tree
    shade_tree(kit,leaf,x,y,scale,rng)

def ground():
    from zhili_garden import palm
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
    for x,y,s in [(-38,-21,.95),(-42,-3,1.08),(-39,19,.87),(42,13,.95),(-3,26,.84)]:
        tree(x,y,s)
    for x,y,height in [(44,-15,5.1),(43.1,-18,3.6),(29.7,-12.2,3.8)]:
        palm(kit,x,y,height,rng)
    for x in (-25,-12,0,13,25):
        box(GROUND,"frame",x,-23.3,.14,.28,.38,.15);box(GROUND,"brass",x,-23.3,.29,.18,.26,.03)

def build(folder, studio=False):
    kit.palette.update({"bark":"655f51","palmstem":"777466","palmring":"a29b86","palmleaf":"3f6342"})
    kit.OUT=Path(folder);kit.OUT.mkdir(exist_ok=True,parents=True);kit.palette.update(palette);kit.start();rng.seed(301)
    for key in PANES+["frame"]:
        shader=kit.materials[key].node_tree.nodes.get("Principled BSDF")
        shader.inputs["Metallic"].default_value=.54 if key!="frame" else .35
        shader.inputs["Roughness"].default_value=.22 if key!="frame" else .43
    steel=kit.materials["railsteel"].node_tree.nodes.get("Principled BSDF")
    steel.inputs["Metallic"].default_value=.84;steel.inputs["Roughness"].default_value=.31
    lamp=kit.materials["fixture"].node_tree.nodes.get("Principled BSDF")
    lamp.inputs["Emission Color"].default_value=(.93,.91,.78,1)
    lamp.inputs["Emission Strength"].default_value=.50
    options=[Path("C:/Windows/Fonts/msyhbd.ttc"),Path("/System/Library/Fonts/PingFang.ttc"),Path("/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc")]
    font=next((bpy.data.fonts.load(str(p)) for p in options if p.exists()),None)
    if not font:raise RuntimeError("A Chinese outline font is required for the building lettering.")
    tower();curved_wing("L1 | Arc west",-43,15,-10,26,2.7,9,24)
    curved_wing("L2 | Arc east",15,24,43,18,1.55,10,22)
    entrance(font);ground()
    import zhili_surfaces
    kit.finish("Zhili", prepare_mesh=zhili_surfaces.apply_to_game_meshes)
    if studio:
        import zhili_studio
        zhili_studio.prepare(Path(folder))
