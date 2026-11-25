"""Close-range ground cover for the architectural photographs, in metres."""
import math
import random

import bpy
from mathutils import Vector

def shade_tree(kit, leaf, x, y, scale, rng):
    group=f"Planting | canopy ({x},{y})"
    origin=Vector((x,y,.16))
    def limb(a,b,r,s):
        direction=(b-a).normalized()
        side=direction.cross(Vector((0,1,0))).normalized()
        across=direction.cross(side)
        ring=[side*math.cos(i*math.tau/7)+across*math.sin(i*math.tau/7) for i in range(7)]
        v=[tuple(origin+(p+t*w)*scale) for p,w in [(a,r),(b,s)] for t in ring]
        kit.shape(group,"bark",v,[(j,(j+1)%7,(j+1)%7+7,j+7) for j in range(7)])
    foot=Vector((0,0,0)); fork=Vector((.18,-.19,1.92))
    limb(foot,fork,.23,.176)
    for k in range(8):
        az=k*2.4+rng.random()*.55
        radial=Vector((math.cos(az),math.sin(az),0));side=Vector((-radial.y,radial.x,0))
        low=fork+radial*.18+Vector((0,0,.17*k))
        limb(fork,low,.165,.115)
        shoulder=low+radial*rng.uniform(.55,1.15)+side*rng.uniform(-.4,.4)+Vector((0,0,1.26))
        limb(low,shoulder,.108,.07)
        for j in range(4):
            elbow=shoulder+radial*rng.uniform(.62,1.54)+side*rng.uniform(-1.1,1.1)+Vector((0,0,rng.uniform(.48,1.18)))
            limb(shoulder,elbow,.064,.035)
            for k2 in range(6):
                tip=elbow+radial*rng.uniform(.2,1.15)+side*rng.uniform(-.85,.85)+Vector((0,0,rng.uniform(-.18,.89)))
                limb(elbow,tip,.032,.009)
                for _ in range(34):
                    a=rng.uniform(0,math.tau);r=rng.random()**.55*.70
                    p=tip+Vector((math.cos(a)*r,math.sin(a)*r,rng.uniform(-.30,.38)-.17*r))
                    c=origin+p*scale
                    leaf(*c,scale*rng.uniform(.12,.23),rng.choice(("myrtle","myrtle","laurel","leafshade","newleaf")),
                         a,rng.uniform(-1.7,.65),group)


def palm(kit, x, y, height, rng):
    """Arching fan of discrete paired leaflets on each rachis, as at the B steps."""
    group="Planting | step palms"
    tilt=Vector((rng.uniform(-.12,.12)*height,rng.uniform(-.08,.08)*height,0))
    def ring(cx,cy,z,r):
        return [(cx+math.cos(j*math.tau/10)*r,cy+math.sin(j*math.tau/10)*r,z) for j in range(10)]
    def centre(t):
        return Vector((x,y,.16+height*t))+tilt*t*t
    for i in range(22):
        t=i/22;u=(i+1)/22
        a,b=centre(t),centre(u)
        r=.11*height**.42*(1-.33*t)
        verts=ring(*a,r)+ring(*b,r*.93)
        kit.shape(group,"palmstem" if i%5 else "palmring",verts,
                  [(j,(j+1)%10,(j+1)%10+10,j+10) for j in range(10)])
    crown=centre(1)
    for n in range(15):
        angle=n*2.39996+rng.uniform(-.2,.2)
        forward=Vector((math.cos(angle),math.sin(angle),0))
        side=Vector((-forward.y,forward.x,0))
        length=height*rng.uniform(.43,.64)
        arch=rng.uniform(.19,.42); droop=rng.uniform(.13,.29)
        def point(t):
            return crown+forward*length*t+Vector((0,0,length*(arch*math.sin(math.pi*t)-droop*t*t)))
        last=point(0)
        for i in range(1,28):
            t=i/28;mid=point(t)
            kit.shape(group,"laurel",[tuple(last-side*.018),tuple(last+side*.018),
                      tuple(mid+side*.011),tuple(mid-side*.011)],[(0,1,2,3)])
            for sign in (-1,1):
                span=length*(.035+.22*(math.sin(math.pi*t)**.72))*rng.uniform(.84,1.1)
                root=mid+forward*sign*.009
                tip=root+side*span*sign+forward*span*.44+Vector((0,0,-span*(.33+.45*t)))
                along=root.lerp(tip,.43); along.z+=span*.23
                width=forward*min(.036,span*.09)
                kit.shape(group,rng.choice(("palmleaf","myrtle","palmleaf","laurel")),
                          [tuple(root),tuple(along+width),tuple(tip),tuple(along-width),
                           tuple(along+Vector((0,0,.024)))],[(0,1,4),(1,2,4),(2,3,4),(3,0,4)])
            last=mid


def grow_lawns(scene):
    rng = random.Random(381)
    # Shared with the grass rectangles in zhili.ground(). Grass stays inside the kerbs.
    lawns = [(-23,-22,22,9),(2,-22,19,10),(-32,1,9,10),(19,-17,7,4),(23,17,8,8)]
    shades = [("Deep turf",(.073,.13,.035)),("Mown grass",(.16,.235,.068)),
              ("Pale tips",(.22,.29,.085)),("New grass",(.117,.19,.045))]
    mats=[]
    for name,color in shades:
        mat=bpy.data.materials.new(name)
        mat.diffuse_color=(*color,1); mat.use_nodes=True
        shader=mat.node_tree.nodes.get("Principled BSDF")
        shader.inputs["Base Color"].default_value=(*color,1)
        shader.inputs["Roughness"].default_value=.87
        shader.inputs["Subsurface Weight"].default_value=.035
        mats.append(mat)
    # Five reusable 0.9 m sod patches. Linked mesh instances preserve fine silhouettes.
    patches=[]
    for n in range(5):
        verts=[];faces=[];colors=[]
        for _ in range(120):
            x,y=rng.uniform(-.44,.44),rng.uniform(-.44,.44)
            phase=rng.random()*math.tau
            grass_color=rng.choices(range(4),weights=(2,5,1,4))[0]
            for b in range(rng.randint(3,6)):
                a=phase+b*2.39+rng.uniform(-.4,.4);c,s=math.cos(a),math.sin(a)
                h=rng.uniform(.039,.093); lean=rng.uniform(.023,.063);w=rng.uniform(.003,.008)
                i=len(verts)
                verts.extend([(x-w*s,y+w*c,0),(x+w*s,y-w*c,0),
                              (x+.43*lean*c+w*.58*s,y+.43*lean*s-w*.58*c,h*.69),
                              (x+.43*lean*c-w*.58*s,y+.43*lean*s+w*.58*c,h*.69),
                              (x+lean*c,y+lean*s,h)])
                faces.extend([(i,i+1,i+2,i+3),(i+3,i+2,i+4)]);colors.extend((grass_color,grass_color))
        mesh=bpy.data.meshes.new("Cut turf %d"%n);mesh.from_pydata(verts,[],faces);mesh.update()
        for mat in mats:mesh.materials.append(mat)
        mesh.polygons.foreach_set("material_index",colors);patches.append(mesh)
    collection=bpy.data.collections.new("Courtyard | lawn cover")
    scene.collection.children.link(collection)
    for cx,cy,w,d in lawns:
        nx,ny=round(w/.90),round(d/.90)
        for ix in range(nx):
            for iy in range(ny):
                obj=bpy.data.objects.new("Turf",rng.choice(patches));collection.objects.link(obj)
                obj.location=(cx-w/2+(ix+.5)*w/nx,cy-d/2+(iy+.5)*d/ny,.251)
                obj.scale=(w/nx/.90,d/ny/.90,rng.uniform(.73,1.27))
                obj.rotation_euler.z=rng.randrange(4)*math.pi*.5
