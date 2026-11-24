"""A full-scale rain shelter study at Zhili C. Blender 5.1 / Cycles."""
from pathlib import Path
from math import pi, sin, cos
import math
import random
import sys
import bpy
from mathutils import Matrix, Vector


class Corridor:
    def __init__(self, artwork):
        self.scene = bpy.context.scene
        self.artwork = Path(artwork)
        self.rng = random.Random(6218)
        self.mats = {}
        self.profiles = {}

    def group(self, name):
        self.collection = bpy.data.collections.new(name)
        self.scene.collection.children.link(self.collection)

    def surface(self, name, color, rough=.52, metal=0, grain=0, emission=0):
        mat = bpy.data.materials.new(name)
        mat.diffuse_color = (*color, 1)
        mat.use_nodes = True
        tree = mat.node_tree
        shader = tree.nodes.get("Principled BSDF")
        for key, value in [("Base Color", (*color, 1)), ("Roughness", rough), ("Metallic", metal)]:
            shader.inputs[key].default_value = value
        if emission:
            shader.inputs["Emission Color"].default_value = (*color, 1)
            shader.inputs["Emission Strength"].default_value = emission
        if grain:
            coord = tree.nodes.new("ShaderNodeNewGeometry").outputs["Position"]
            def noise(scale, detail):
                n = tree.nodes.new("ShaderNodeTexNoise")
                tree.links.new(coord, n.inputs["Vector"])
                n.inputs["Scale"].default_value = scale
                n.inputs["Detail"].default_value = detail
                return n.outputs["Fac"]
            def ramp(fac, lo, hi, inp, start=.22, end=.78):
                n = tree.nodes.new("ShaderNodeValToRGB")
                for e, rgb, pos in zip(n.color_ramp.elements, [lo,hi], [start,end]):
                    e.position=pos; e.color=(*rgb,1)
                tree.links.new(fac,n.inputs[0]);tree.links.new(n.outputs[0],shader.inputs[inp])
            coarse=noise(.9 if metal==0 else 4.7,5)
            ramp(coarse, [v*(1-grain) for v in color], [v*(1+grain*.44) for v in color], "Base Color")
            lo=max(.05,rough-grain*.41); hi=min(.95,rough+grain*.43)
            ramp(noise(2.8,4),[lo]*3,[hi]*3,"Roughness")
            bump = tree.nodes.new("ShaderNodeBump")
            bump.inputs["Strength"].default_value=.16
            bump.inputs["Distance"].default_value=.0009 if metal else .0025
            tree.links.new(noise(235 if metal else 135,2),bump.inputs["Height"])
            tree.links.new(bump.outputs["Normal"],shader.inputs["Normal"])
        self.mats[name]=mat
        return mat

    def object(self, name, mesh, loc):
        obj=bpy.data.objects.new(name,mesh)
        self.collection.objects.link(obj);obj.location=loc
        return obj

    def box(self,name,xyz,dims,mat, bevel=.006):
        key=(tuple(dims),mat,bevel)
        if key not in self.profiles:
            x,y,z=[n*.5 for n in dims]
            verts=[(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]
            faces=[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
            mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.materials.append(self.mats[mat]);mesh.update()
            self.profiles[key]=mesh
        obj=self.object(name,self.profiles[key],xyz)
        if bevel:
            mod=obj.modifiers.new("Edge reflection","BEVEL");mod.width=min(bevel,min(dims)*.32);mod.segments=3
            mod=obj.modifiers.new("Face normals","WEIGHTED_NORMAL");mod.keep_sharp=True
        return obj

    def pipe(self,name,a,b,r,mat,n=12):
        va,vb=Vector(a),Vector(b)
        vec=vb-va; length=vec.length
        key=(mat,r,n)
        if key not in self.profiles:
            verts=[(r*cos(k*2*pi/n),r*sin(k*2*pi/n),z) for z in (-.5,.5) for k in range(n)]
            faces=[tuple(reversed(range(n))),tuple(range(n,n*2))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
            mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.materials.append(self.mats[mat]);mesh.update()
            for p in list(mesh.polygons)[2:]:p.use_smooth=True
            self.profiles[key]=mesh
        o=self.object(name,self.profiles[key],(va+vb)*.5)
        o.scale.z=length;o.rotation_euler=vec.to_track_quat("Z","Y").to_euler()
        return o

    def light(self,name,loc,target,color,power,sizes):
        light=bpy.data.lights.new(name,'AREA')
        light.shape='RECTANGLE';light.size,light.size_y=sizes
        light.energy=power;light.color=color
        o=self.object(name,light,loc);o.rotation_euler=(Vector(target)-Vector(loc)).to_track_quat('-Z','Y').to_euler()
        return o

    def print(self, name, center, width, height, side="right", tilt=0):
        # Plane normal faces towards the visitor; UV axes follow the printed page.
        mat=self.mats.get(name)
        if mat is None:
            mat=self.surface(name,(.7,.68,.6),.47)
            nodes=mat.node_tree.nodes
            tex=nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(self.artwork/(name+'.png')))
            tex.image.pack();mat.node_tree.links.new(tex.outputs['Color'],nodes.get('Principled BSDF').inputs['Base Color'])
        right=Vector((0,-1,0)) if side=="right" else Vector((1,0,0))
        up=Vector((0,0,1)); horizontal=right*cos(tilt)+up*sin(tilt); vertical=up*cos(tilt)-right*sin(tilt)
        uv=[(0,0),(1,0),(1,1),(0,1)]
        verts=[horizontal*((x-.5)*width)+vertical*((y-.5)*height) for x,y in uv]
        mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],[(0,1,2,3)]);mesh.materials.append(mat);mesh.update()
        layer=mesh.uv_layers.new()
        for i,coord in enumerate(uv):layer.data[i].uv=coord
        return self.object(name,mesh,center)

    def palette(self):
        self.surface("aged putty",(.47,.48,.405),.72,grain=.16)
        self.surface("warm enamel",(.40,.43,.365),.36,.18,.23)
        self.surface("skirting",(.119,.13,.116),.44,grain=.36)
        self.surface("expansion joint",(.052,.049,.04),.78,grain=.2)
        self.surface("zinc",(.32,.35,.33),.27,.83,.27)
        self.surface("satin silver",(.57,.62,.59),.21,.93,.24)
        self.surface("chrome",(.72,.78,.75),.135,.95,.16)
        self.surface("rubber",(.02,.024,.022),.63,grain=.34)
        self.surface("ceiling",(.39,.406,.345),.67,grain=.24)
        self.surface("aluminium blue",(.092,.135,.145),.33,.71,.26)
        self.surface("blue ink",(.036,.092,.137),.35,.25,.18)
        self.surface("chalk",(.73,.71,.61),.74,grain=.2)
        self.surface("teak",(.185,.10,.049),.41,grain=.46)
        self.surface("cork",(.29,.198,.103),.84,grain=.35)
        self.surface("slate",(.068,.083,.081),.42,grain=.31)
        self.surface("leaf green",(.047,.098,.052),.49,grain=.32)
        self.surface("leaf light",(.102,.167,.065),.43,grain=.29)
        self.surface("bark",(.077,.054,.033),.79,grain=.51)
        self.surface("amber room",(1,.66,.33),.55,emission=2.9)
        self.surface("exit green",(.23,.78,.44),.44,emission=1.7)
        self.surface("lamp opal",(.89,1,.88),.33,emission=7)
        self.surface("old opal",(.93,.89,.67),.38,emission=3)
        self.surface("maroon",(.24,.051,.033),.38,.29,.3)
        self.surface("wet basalt",(.047,.062,.064),.17,grain=.26)
        for i in range(5):
            v=1+i*.042
            self.surface("stone "+str(i),tuple(v*k for k in (.266,.26,.222)),.259,.03,.24)
        self.surface("aged paper",(.58,.54,.395),.74,grain=.26)
        glass=self.surface("rain glass",(.84,.91,.88),.035)
        shader=glass.node_tree.nodes.get("Principled BSDF")
        shader.inputs["Transmission Weight"].default_value=1;shader.inputs["IOR"].default_value=1.46
        self.surface("drops",(.77,.88,.89),.06)
        self.mats["drops"].node_tree.nodes.get("Principled BSDF").inputs["Transmission Weight"].default_value=1
        self.surface("celadon",(.19,.31,.265),.37,grain=.16)
        self.surface("book red",(.28,.072,.047),.49,grain=.12)
        self.surface("ivory pages",(.64,.57,.43),.72,grain=.13)

    def shell(self):
        self.group("01  •  Shell, bay joints and terrazzo")
        box=self.box;rng=self.rng
        box("Slab / recessed joints",(0,4.5,-.095),(6.5,20,.15),"expansion joint")
        for col in range(-5,6):
            for row in range(-6,18):
                box("Honed stone / 750", (col*.75,row*.75,-.021),(.746,.746,.039),"stone "+str(rng.randrange(5)),.0018)
        box("East plaster wall",(3.00,4.4,1.73),(.16,17.0,3.50),"aged putty")
        box("Return / stair lobby",(0,11.75,1.73),(6.12,.15,3.50),"aged putty")
        box("Rear wall",(.0,-4.07,1.73),(6.12,.15,3.5),"aged putty")
        for side in [-1,1]:
            box("Wall plinth",(side*2.9,4.25,.10),(.09,16.45,.20),"skirting")
        box("Cross plinth",(0,11.65,.10),(5.8,.12,.2),"skirting")
        box("Panel joints",(0,3.9,3.52),(6.32,16.5,.18),"skirting")
        for col in range(-2,3):
            for row in range(-3,11):
                box("Fibre cement ceiling",(col*1.22,row*1.18,3.405),(1.215,1.174,.055),"ceiling",.003)
        for y in (-3.6,1.5,6.6,11.55):
            box("Window pier",(-2.99,y,1.70),(.25,.24,3.4),"aged putty")
        for i in range(12):
            y=-3.55+i*1.267
            box("Powdercoat jamb",(-2.94,y,1.7),(.097,.052,3.37),"aluminium blue")
            if i<12:
                box("Laminated pane",(-2.986,y+.64,1.73),(.009,1.225,3.17),"rain glass",0)
        for z in (.14,1.0,2.67,3.31):
            box("Horizontal glazing bar",(-2.934,3.97,z),(.10,15.5,.054),"aluminium blue")
            box("Anodised trim",(-2.878,3.97,z+.015),(.014,15.5,.012),"zinc",.003)
        for j in range(59):
            box("Glazing safety frit",(-2.975,-3.35+j*.245,1.265),(.002,.081,.021),"warm enamel",0)
        for z in (.18,3.20):
            box("Rear glazing trim",(-2.90,3.97,z),(.09,15.5,.038),"rubber")
        # Long drain and heel mat at the threshold.
        box("Entrance ribbed mat",(-.56,-.64,.010),(1.63,1.08,.017),"rubber")
        for j in range(34):
            box("Recessed rib",(-.56,-1.16+j*.031,.019),(1.60,.008,.0035),"skirting",0)
        box("Drain frame",(1.84,2.57,.003),(.18,1.56,.009),"satin silver")
        for j in range(40):
            box("Drain slot",(1.84,1.83+j*.0375,.010),(.138,.012,.003),"rubber",0)

    def fixtures(self):
        self.group("02  •  Fluorescent luminaires and services")
        box=self.box;pipe=self.pipe
        for i,y in enumerate((-1.4,2.85,7.15,10.65)):
            x=.23 if i!=2 else .19
            box("Galvanised housing",(x,y,3.327),(1.26,.237,.071),"zinc")
            box("Reflector",(x,y,3.284),(1.22,.21,.036),"chalk")
            color=(.85,1,.91) if i%2==0 else (1,.94,.82)
            for yy in [y-.052,y+.052]:
                pipe("28 mm opal T5",(x-.56,yy,3.25),(x+.56,yy,3.25),.018,"lamp opal" if i!=2 else "old opal",24)
                for xx in [x-.581,x+.581]:
                    box("Lamp socket",(xx,yy,3.255),(.044,.052,.064),"warm enamel")
            self.light("Fluorescent wash",(x,y,3.22),(x,y,0),color,[56,76,52,60][i],(1.10,.17))
        for y in [-3.0,4.47,8.21]:
            box("Return air grille",(1.64,y,3.369),(.34,.40,.022),"slate",.002)
            for j in range(9):box("Louvre",(1.64,y-.17+j*.041,3.351),(.30,.015,.013),"zinc",.002)
        for z in [2.90,2.975]:
            pipe("Wall conduit",(-2.65,11.58,z),(-.74,11.58,z),.024,"warm enamel")
            pipe("Service riser",(-.74,11.58,z),(-.74,11.58,2.56),.024,"warm enamel")
        for j in range(7):
            box("Expansion cap",(2.898,-3.5+j*2.3,2.84),(.042,.15,.18),"warm enamel")
        pipe("Electrical line",(2.902,-3.65,2.84),(2.902,11.47,2.84),.018,"zinc")

    def fittings(self):
        self.group("03  •  Benches, notice cases and drinking point")
        box=self.box;pipe=self.pipe
        for cy in (1.75,6.18):
            for j in range(5):
                box("Bench / slatted seat",(-2.48+j*.098,cy,.455),(.086,2.56,.043),"zinc",.017)
            for z in (.71,.85):
                box("Bench / back slat",(-2.56,cy,z),(.047,2.56,.105),"zinc",.01)
            for s in (-.97,.97):
                y=cy+s
                pipe("Bench leg",(-2.52,y,.035),(-2.52,y,.835),.027,"aluminium blue")
                pipe("Bench leg",(-2.09,y,.035),(-2.09,y,.446),.028,"aluminium blue")
                box("Cross rail",(-2.30,y,.416),(.51,.05,.052),"slate")
                for x in [-2.52,-2.09]:
                    box("Rubber foot",(x,y,.014),(.087,.064,.029),"rubber")
                for z in (.71,.85):pipe("Coach bolt",(-2.55,y,z),(-2.524,y,z),.011,"chrome")
        for i,(y,print_name) in enumerate([(3.80,"field-notes"),(5.16,"walking")]):
            box("Wall cabinet / shadow line",(2.88,y,1.72),(.088,1.23,1.66),"slate")
            box("Linen bulletin backing",(2.827,y,1.72),(.028,1.15,1.56),"cork")
            for side in (-1,1):
                box("Silver case jamb",(2.80,y+side*.598,1.72),(.091,.034,1.66),"zinc")
                box("Silver case rail",(2.80,y,1.72+side*.812),(.091,1.21,.037),"zinc")
            self.print(print_name,(2.803,y,1.73),.99,1.40,tilt=.007*(-1)**i)
            for dz in [-.71,.72]:
                for dy in [-.48,.48]:
                    pipe("Pin",(2.799,y+dy,1.73+dz),(2.791,y+dy,1.73+dz),.009,"chrome")
            box("Case glazing",(2.775,y,1.72),(.006,1.15,1.57),"rain glass",0)
            pipe("Barrel lock",(2.775,y-.52,1.00),(2.758,y-.52,1.),.025,"chrome")
        box("Identification plate",(2.865,.81,1.99),(.081,1.67,.64),"aluminium blue")
        self.print("zhili-plate",(2.817,.81,1.99),1.61,.60)
        for y in (.031,1.59):
            for z in (1.725,2.25):pipe("Mounting screw",(2.817,y,z),(2.810,y,z),.008,"satin silver")
        # Stainless drinking fountain. A depressed trough has a rim, drain, bibs and valves.
        cy=1.08
        box("Brushed steel body",(2.65,cy,.51),(.47,1.53,.89),"zinc",.019)
        box("Recessed kick",(2.66,cy,.06),(.39,1.4,.12),"rubber")
        box("Splashback",(2.84,cy,1.16),(.052,1.6,.51),"satin silver")
        for y in [cy-.75,cy+.75]:box("Pressed end",(2.59,y,.992),(.58,.045,.12),"satin silver",.018)
        box("Front lip",(2.32,cy,.991),(.059,1.51,.107),"satin silver",.02)
        box("Sloping tray",(2.58,cy,.953),(.49,1.48,.031),"slate")
        for j in range(22):
            pipe("Drain tray bars",(2.38,cy-.67+j*.062,.97),(2.78,cy-.67+j*.062,.97),.007,"satin silver")
        for y in [cy-.36,cy+.36]:
            points=[(2.802,y,1.19),(2.70,y,1.19),(2.65,y,1.23),(2.60,y,1.226),(2.556,y,1.183)]
            for a,b in zip(points,points[1:]):pipe("Bubbler",a,b,.021,"chrome",24)
            pipe("Button collar",(2.70,y+.12,.965),(2.70,y+.12,1.022),.030,"satin silver")
        self.print("water",(2.808,cy,1.337),.46,.14)
        for j in range(20):
            box("Ventilation slots",(2.409,cy-.51+j*.051,.384),(.008,.018,.125),"rubber",.004)
        for dz,w in [(.16,.80),(.64,.84)]:
            box("Service hatch seam",(2.411,cy,dz),(.006,w,.009),"skirting",.001)
        # Umbrella stand, partly open canopy, folded gores, crook handles.
        y=8.53
        for yy in [y-.39,y+.39]:
            for xx in [2.30,2.69]:pipe("Stand leg",(xx,yy,.025),(xx,yy,.55),.017,"zinc")
            pipe("Stand top",(2.30,yy,.55),(2.69,yy,.55),.016,"zinc")
        for x in [2.30,2.69]:pipe("Stand side",(x,y-.39,.55),(x,y+.39,.55),.016,"zinc")
        box("Drip tray",(2.50,y,.088),(.44,.84,.056),"slate")
        for i in range(4):
            yy=y-.24+i*.16
            for j in range(9):
                a=j*2*pi/9
                pipe("Folded canopy",(2.48,yy,.105),(2.43+.055*cos(a),yy+.055*sin(a),.722),.018,"maroon" if i==1 else "blue ink")
            pipe("Umbrella grip",(2.43,yy,.70),(2.43,yy,.91),.014,"teak")
            for j in range(8):
                a=j*pi/8;b=(j+1)*pi/8
                pipe("Curved handle",(2.43,yy+.034*(1-cos(a)),.91+.036*sin(a)),(2.43,yy+.034*(1-cos(b)),.91+.036*sin(b)),.011,"teak")

    def after_class(self):
        self.group("05  •  After class / objects at human scale")
        box=self.box;pipe=self.pipe;r=self.rng
        # A paperback and its folded bookmark break the long horizontal bench slats.
        for z,w,d,h,mat in [(.487,.174,.249,.006,"book red"),(.498,.166,.239,.020,"ivory pages"),(.511,.174,.249,.005,"book red")]:
            o=box("Book left on the bench",(-2.268,1.98,z),(w,d,h),mat,.002);o.rotation_euler.z=-.24
        o=box("Cloth bookmark",(-2.237,1.860,.506),(.017,.069,.003),"blue ink",0);o.rotation_euler.z=-.24
        # Floor-standing campus directory with folded returns, shelf, screws, and ballast.
        x,y=-1.79,7.63
        for xx in [x-.33,x+.33]:
            box("Directory foot",(xx,y,.048),(.084,.49,.062),"slate")
            box("Directory rail",(xx,y,.91),(.042,.053,1.76),"zinc")
        box("Directory / enamel back",(x,y,1.14),(.71,.054,1.14),"aluminium blue")
        self.print("walking",(x,y-.032,1.15),.65,1.01,"end")
        box("Leaflet shelf",(x,y-.09,.59),(.69,.18,.025),"zinc")
        # Repotting table with terracotta mineral rings and a plant grown towards the window.
        x,y=-1.71,10.93
        for xx in (x-.51,x+.51):
            for yy in (y-.24,y+.24):box("Table leg",(xx,yy,.395),(.04,.04,.79),"slate")
        box("Edge-banded table",(x,y,.803),(1.14,.60,.045),"teak",.012)
        for j in range(5):
            box("Plywood grain",(x,y-.298,.807+j*.0045),(1.08,.002,.0012),"ivory pages",0)
        def pot(cx,cy,z,s):
            pipe("Mineral glazed pot",(cx,cy,z),(cx,cy,z+.26*s),.16*s,"celadon",48)
            pipe("Pot rim",(cx,cy,z+.235*s),(cx,cy,z+.265*s),.174*s,"celadon",48)
            pipe("Dark soil",(cx,cy,z+.265*s),(cx,cy,z+.268*s),.15*s,"bark",40)
            for j in range(13):
                a=j*2.4;reach=r.uniform(.15,.34)*s
                start=Vector((cx,cy,z+.26*s));end=start+Vector((cos(a)*reach,sin(a)*reach,r.uniform(.20,.48)*s))
                pipe("Leaf petiole",start,end,.0048*s,"leaf green",8)
                length=r.uniform(.14,.26)*s;dx,dy=cos(a)*length,sin(a)*length
                mid=end+Vector((dx*.53,dy*.53,.04*s))
                tip=end+Vector((dx,dy,-.077*s));wing=Vector((-dy*.35,dx*.35,.02*s))
                mesh=bpy.data.meshes.new("Folded leaf");mesh.from_pydata([end,mid+wing,tip,mid-wing,mid],[],[(0,1,4),(1,2,4),(2,3,4),(3,0,4)])
                mesh.materials.append(self.mats["leaf light" if j%4==0 else "leaf green"]);self.object("Glossy leaves",mesh,(0,0,0))
        pot(x-.21,y,.827,1.2);pot(x+.28,y+.07,.827,.72)
        # Small opening-side notices and the drip-loop to the first-floor room unit.
        self.print("field-notes",(-.83,11.655,1.65),.34,.47,"end",-.025)
        self.print("walking",(-1.18,11.653,1.57),.25,.32,"end",.032)
        box("Room air unit",(-1.62,11.41,2.60),(1.05,.35,.31),"aged paper",.064)
        box("Outlet and louvres",(-1.61,11.241,2.54),(.85,.03,.091),"slate",.009)
        for i in range(5):box("Outlet fin",(-1.61,11.218,2.503+i*.015),(.83,.024,.006),"warm enamel",.002)
        pipe("Condensate",(-1.12,11.40,2.6),(-.93,11.40,2.6),.034,"aged paper")
        pipe("Condensate",(-.93,11.4,2.6),(-.87,11.51,2.46),.034,"aged paper")

    def end_lobby(self):
        self.group("04  •  Lobby and courtyard stair")
        box=self.box;pipe=self.pipe
        # Flush enamel door with kick plate, wire-glass slit and closer.
        for x in (-.23,.85):
            box("Door reveal",(x,11.61,1.09),(.057,.10,2.18),"slate")
        box("Lintel",(.31,11.61,2.18),(1.14,.11,.076),"slate")
        box("Door",(.31,11.625,1.061),(1.02,.063,2.11),"warm enamel")
        box("Door kick",(.31,11.580,.197),(.92,.023,.32),"zinc")
        box("Door light",(.10,11.579,1.57),(.28,.03,.55),"slate")
        for j in range(6):box("Wire glass",(-.018+j*.046,11.562,1.58),(.005,.01,.50),"zinc",0)
        box("Lever",(.69,11.53,1.05),(.17,.067,.027),"chrome")
        box("Closer",(.63,11.546,2.027),(.24,.09,.079),"zinc")
        self.print("zhili-plate",(1.41,11.65,1.73),.68,.25,"end")
        pipe("Clock rim",(.31,11.66,2.77),(.31,11.566,2.77),.231,"zinc",64)
        pipe("Clock face",(.31,11.561,2.77),(.31,11.557,2.77),.207,"chalk",64)
        for j in range(60):
            a=j*pi/30;r=.16 if j%5==0 else .183
            pipe("Dial index",(.31+sin(a)*r,11.55,2.77+cos(a)*r),(.31+sin(a)*.192,11.55,2.77+cos(a)*.192),.0038 if j%5==0 else .0015,"slate")
        for a,r in [(2.47,.12),(4.11,.163)]:pipe("Clock hand",(.31,11.536,2.77),(.31+sin(a)*r,11.536,2.77+cos(a)*r),.007,"rubber")
        for y in (10.92,-3.25):
            box("Exit housing",(2.871,y,.76),(.09,.36,.16),"aluminium blue")
            box("Exit sign",(2.82,y,.76),(.014,.30,.107),"exit green")
            box("Exit dash",(2.805,y,.76),(.01,.18,.016),"chalk")
        for j in range(16):
            box("Courtyard stair",(-5.33-j*.36,8.70,.085+j*.15),(.36,3.2,.17+j*.30),"stone 2",.012)
        for y in (7.2,10.15):
            for j in (0,4,8,12,15):
                z=.17+j*.30; x=-5.30-j*.36
                pipe("Stair baluster",(x,y,z),(x,y,z+.88),.021,"zinc")
            pipe("Handrail",(-5.30,y,1.05),(-10.70,y,5.55),.034,"zinc")
        # The plants are modelled leaves, silhouetted against the opposite classrooms.
        leafmat=["leaf green","leaf light"]
        for idx,(x,y,scale) in enumerate([(-5.7,-2.4,1.0),(-6.2,3.3,.83),(-7.3,12.4,1.1),(-12.9,4.8,1.2)]):
            pipe("Rain tree",(x,y,-.1),(x+.12,y,3.7*scale),.14*scale,"bark")
            verts=[[],[]];faces=[[],[]]
            for j in range(26):
                a=j*2.4; dist=self.rng.uniform(.65,1.95)*scale
                bx=x+cos(a)*dist;by=y+sin(a)*dist;bz=self.rng.uniform(2.3,4.1)*scale
                pipe("Limb",(x,y,1.45*scale),(bx,by,bz),.04*scale,"bark")
                for k in range(85):
                    az=self.rng.uniform(0,2*pi); rad=self.rng.uniform(.01,.94)*scale
                    xx=bx+rad*cos(az);yy=by+rad*sin(az);zz=bz+self.rng.uniform(-.43,.43)*scale
                    length=self.rng.uniform(.09,.24)*scale; a2=self.rng.uniform(0,2*pi);v=self.rng.randrange(2)
                    dx=length*cos(a2);dy=length*sin(a2); n=len(verts[v])
                    verts[v].extend([(xx-dx,yy-dy,zz),(xx-dy*.35,yy+dx*.35,zz+.035),(xx+dx,yy+dy,zz-.035),(xx+dy*.35,yy-dx*.35,zz)])
                    faces[v].append((n,n+1,n+2,n+3))
            for v in range(2):
                mesh=bpy.data.meshes.new("Canopy leaflets");mesh.from_pydata(verts[v],[],faces[v]);mesh.materials.append(self.mats[leafmat[v]])
                self.object("Rain tree canopy",mesh,(0,0,0))

    def exterior(self):
        self.group("05  •  Rain, court and adjacent teaching bays")
        box=self.box
        box("Wet court",(-12,4,-.16),(22,45,.20),"wet basalt")
        for y in range(-19,30,3):
            box("Covered teaching wing",(-15.8,y,3.6),(.54,3,7.2),"skirting")
            for z in (1.9,5.1):
                for j in range(3):
                    box("Window",(-15.51,y-.96+j*.94,z),(.04,.86,1.51),"amber room" if self.rng.random()<.27 else "aluminium blue")
                box("Gallery ledge",(-15.02,y,z-1.14),(1.56,3.0,.17),"aged putty")
        for y in (-8,-2,4,10,16):
            fill=self.light("Blue hour / wet tree",(-6.8,y,5.2),(-3.7,y+.5,1.1),(.44,.62,.9),78,(3,2))
            fill.visible_camera=False;fill.visible_transmission=False;fill.visible_glossy=False
        # Beaded rain is on the outside face and obeys gravity; shared mesh limits overhead.
        verts=[];faces=[]
        for _ in range(2500):
            y=self.rng.uniform(-3.5,11.45);z=self.rng.uniform(.18,3.28)
            length=self.rng.uniform(.004,.024);width=self.rng.uniform(.0014,.0043);idx=len(verts)
            verts.extend([(-2.997,y-width,z),(-2.997,y,z+length),(-2.997,y+width,z),(-2.997,y,z-width),(-3.001,y,z+.001)])
            faces.extend([(idx+i,idx+(i+1)%4,idx+4) for i in range(4)])
        mesh=bpy.data.meshes.new("Window condensation");mesh.from_pydata(verts,[],faces);mesh.materials.append(self.mats["drops"])
        self.object("Rain beads",mesh,(0,0,0))

    def camera(self,name,xyz,look,lens,panorama=False):
        data=bpy.data.cameras.new(name);o=self.object(name,data,xyz)
        o.rotation_euler=(Vector(look)-Vector(xyz)).to_track_quat('-Z','Y').to_euler()
        data.lens=lens;data.clip_start=.025
        if panorama:data.type='PANO';data.panorama_type='EQUIRECTANGULAR'
        return o

    def finish(self):
        s=self.scene
        s.render.engine='CYCLES';s.cycles.samples=48;s.cycles.use_denoising=True
        s.cycles.max_bounces=8;s.cycles.transmission_bounces=6;s.cycles.transparent_max_bounces=8
        s.world=bpy.data.worlds.new("Monsoon / ambient");s.world.use_nodes=True
        bg=s.world.node_tree.nodes.get("Background");bg.inputs[0].default_value=(.17,.24,.33,1);bg.inputs[1].default_value=.16
        s.view_settings.view_transform='AgX';s.view_settings.look='AgX - Medium High Contrast';s.view_settings.exposure=.32
        s.render.resolution_x=1440;s.render.resolution_y=960;s.render.resolution_percentage=100
        self.group("06  •  Visitor cameras")
        s.camera=self.camera("Threshold",(-1.0,-3.35,1.56),(.63,6.6,1.49),23.5)
        self.camera("At the notices",(-.32,4.94,1.57),(2.71,3.95,1.63),31)
        for name,loc in [("Pano threshold",(-1.0,-3.35,1.56)),("Pano bench",(-.33,2.64,1.55)),("Pano notices",(-.17,7.14,1.55))]:
            self.camera(name,loc,(loc[0],loc[1]+8,loc[2]),26,True)
        s.render.image_settings.file_format="PNG";s.render.filepath="//rain-threshold.png"
        for area in bpy.context.screen.areas:
            if area.type=="VIEW_3D":area.spaces.active.region_3d.view_perspective='CAMERA'

def build(folder):
    folder=Path(folder);folder.mkdir(exist_ok=True,parents=True)
    # A separate scene in a fresh Blender process; leave the published exterior intact.
    scene=bpy.data.scenes.new("致理楼 C · 雨夜连廊");bpy.context.window.scene=scene
    c=Corridor(folder/'prints');c.palette();c.shell();c.fixtures();c.fittings();c.end_lobby();c.exterior();c.after_class();c.finish()
    bpy.ops.wm.save_as_mainfile(filepath=str(folder/"Rain-corridor.blend"),compress=True)

if __name__ == '__main__':
    build(sys.argv[sys.argv.index('--')+1])
