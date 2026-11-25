"""Street furniture for the front of the C arcade. Local units are metres."""
import math
import bpy
from mathutils import Vector

TAU = math.tau
GROUP = "Street | Cycles at the arcade"


def finish(name, hex_color, metal, rough):
    key = "Cycle finish | " + name
    mat = bpy.data.materials.get(key)
    if mat:
        return mat
    rgb = [int(hex_color[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    linear = [v / 12.92 if v < .04045 else ((v + .055) / 1.055) ** 2.4 for v in rgb]
    mat = bpy.data.materials.new(key)
    mat.diffuse_color = (*linear, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = mat.diffuse_color
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    if name in ("Lagoon", "Honey", "Oxblood"):
        bsdf.inputs["Coat Weight"].default_value = .48
    return mat


class Fabrication:
    def __init__(self):
        self.vertices, self.faces, self.face_mats, self.materials = [], [], [], []

    def face(self, indices, material):
        if material not in self.materials:
            self.materials.append(material)
        self.faces.append(indices)
        self.face_mats.append(self.materials.index(material))

    def section(self, points, material, closed=False):
        start = len(self.vertices)
        size = len(points[0])
        self.vertices.extend(v for ring in points for v in ring)
        for i in range(len(points) if closed else len(points) - 1):
            a, b = start + i * size, start + (i + 1) % len(points) * size
            for j in range(size):
                k = (j + 1) % size
                self.face((a + j, a + k, b + k, b + j), material)
        if not closed:
            self.face(tuple(start + j for j in reversed(range(size))), material)
            end = start + size * (len(points) - 1)
            self.face(tuple(end + j for j in range(size)), material)

    def tube(self, line, radius, mat, sides=8, closed=False):
        points = [Vector(p) for p in line]
        rings = []
        for i, point in enumerate(points):
            prev = points[i - 1 if i or closed else 0]
            nxt = points[(i + 1) % len(points)] if closed or i + 1 < len(points) else point
            tangent = (nxt - prev).normalized()
            if i == 0:
                axis = min((Vector((1,0,0)), Vector((0,1,0)), Vector((0,0,1))),
                           key=lambda a: abs(a.dot(tangent)))
            axis = (axis - tangent * axis.dot(tangent)).normalized()
            normal = tangent.cross(axis)
            rings.append([point + radius * (axis * math.cos(j*TAU/sides) + normal * math.sin(j*TAU/sides)) for j in range(sides)])
        self.section(rings, mat, closed)

    def rounded(self, rings, mat):
        self.section([[(x + a*math.cos(j*TAU/20), y + b*math.sin(j*TAU/20), z)
                      for j in range(20)] for x,y,z,a,b in rings], mat)

    def install(self, name, collection, loc, angle):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(self.vertices, [], self.faces)
        for mat in self.materials:
            mesh.materials.append(mat)
        for poly, index in zip(mesh.polygons, self.face_mats):
            poly.material_index = index
            poly.use_smooth = len(poly.vertices) == 4
        mesh.update()
        obj = bpy.data.objects.new(name, mesh)
        collection.objects.link(obj)
        obj.location = loc
        obj.rotation_euler.z = math.radians(angle)
        return obj


def bicycle(m, paint, guards=True):
    f = Fabrication()
    def bar(a,b,r,mat): f.tube([a,b],r,mat)
    rubber, rim, steel, alloy, leather, amber, red = (m[k] for k in ("Tyre","Rim","Steel","Graphite","Saddle","Amber","Red"))
    def hoop(x,y,z,r,t,mat):
        f.tube([(x + r*math.cos(i*TAU/64),y,z + r*math.sin(i*TAU/64)) for i in range(64)],
               t,mat,10,True)
    for rear, cx in enumerate((.56,-.51)):
        hoop(cx,0,.338,.319,.019,rubber)
        hoop(cx,0,.338,.294,.013,rim)
        hoop(cx,-.009,.338,.308,.0033,m["Sidewall"])
        hoop(cx,.009,.338,.308,.0033,m["Sidewall"])
        bar((cx,-.044,.338),(cx,.044,.338),.026,alloy)
        for i in range(32):
            a = i*TAU/32
            hand = 1 if i%2 else -1
            b = a + (.60 if i%4 in (0,1) else -.60)
            bar((cx+.032*math.cos(b),hand*.027,.338+.032*math.sin(b)),
                (cx+.29*math.cos(a),hand*.004,.338+.29*math.sin(a)),.00165,rim)
        if guards:
            arc = [math.radians(a) for a in range(15 if rear else 56, 175 if rear else 202, 4)]
            f.section([[(cx + (.357+rise)*math.cos(a), y, .338 + (.357+rise)*math.sin(a))
                        for y,rise in [(-.027,0),(-.025,.005),(-.014,.012),(.014,.012),(.025,.005),(.027,0),(.023,-.002),(-.023,-.002)]] for a in arc],paint)
            for side in (-1,1):
                bar((cx,side*.043,.338),(cx-.31,side*.023,.53),.0035,rim)
        a=.9 if rear else -2.3
        bar((cx+.19*math.cos(a),.008,.338+.19*math.sin(a)),
            (cx+.247*math.cos(a),.008,.338+.247*math.sin(a)),.009,amber)
    crank=(-.03,0,.309)
    seat=(-.192,0,.767)
    head=(.381,0,.790)
    bar(crank,seat,.021,paint)
    f.tube([head,(.353,0,.68),(.24,0,.553),(.11,0,.431),(.048,0,.396),(-.056,0,.38)],.028,paint,12)
    f.tube([(.38,0,.72),(.23,0,.455),(.108,0,.342),crank],.0185,paint)
    for side in (-1,1):
        axle=(-.51,side*.051,.338)
        bar((-.17,side*.013,.7),axle,.0105,paint)
        bar((-.03,side*.029,.306),axle,.013,paint)
        f.tube([(.406,side*.025,.693),(.438,side*.036,.60),(.484,side*.045,.43),(.512,side*.048,.37),(.56,side*.048,.338)],.014,paint)
    bar((.366,0,.818),(.41,0,.695),.031,paint)
    bar((.374,0,.795),(.347,0,.921),.0125,rim)
    bar((.347,0,.92),(.411,0,.953),.0145,rim)
    for s in (-1,1):
        f.tube([(.411,0,.953),(.415,s*.113,.954),(.408,s*.173,.972),(.374,s*.217,1.003),(.24,s*.27,1.007)],.0105,rim)
        bar((.238,s*.271,1.007),(.323,s*.245,1.006),.016,rubber)
        f.tube([(.338,s*.238,.99),(.32,s*.204,.975),(.257,s*.215,.966)],.0045,rim)
        f.tube([(.335,s*.233,.981),(.37,s*.218,.943),(.471,s*.16,.853),(.47,s*.075,.723),(.48,s*.03,.627)],.0028,rubber)
    bar((-.191,0,.762),(-.215,0,.855),.012,rim)
    for s in (-1,1):
        f.tube([(-.325,s*.05,.843),(-.25,s*.043,.816),(-.16,s*.028,.822),(-.101,s*.012,.857)],.0045,steel)
    f.rounded([(-.24,0,.84,.112,.065),(-.237,0,.857,.131,.088),(-.23,0,.878,.131,.089),(-.233,0,.89,.115,.075)],leather)
    f.rounded([(-.14,0,.856,.086,.030),(-.125,0,.872,.083,.039),(-.123,0,.882,.075,.030)],leather)
    # Front basket. The top flares out, including at the four rounded corners.
    def basket_loop(frac):
        cx=.654+.018*frac
        rx,ry=.128+.045*frac,.145+.049*frac
        pts=[]
        for i in range(40):
            a=TAU*i/40
            u,v=math.cos(a),math.sin(a)
            pts.append((cx+rx*math.copysign(abs(u)**.42,u), ry*math.copysign(abs(v)**.42,v),.707+.195*frac))
        return pts
    for j in range(6): f.tube(basket_loop(j/5),.0052 if j==5 else .0022,alloy,6,True)
    lo,hi=basket_loop(0),basket_loop(1)
    for i in range(40): bar(lo[i],hi[i],.0019,alloy)
    for s in (-1,1):
        bar((.56,s*.052,.338),(.70,s*.10,.705),.0047,steel)
        bar((.39,s*.025,.766),(.54,s*.076,.73),.0055,alloy)
    # Wire carrier, chain guard, two pedals and compact kickstand.
    for y in (-.064,-.027,.027,.064):
        bar((-.687,y,.726),(-.333,y,.726),.0055,rim)
    for x in (-.686,-.56,-.334):bar((x,-.064,.726),(x,.064,.726),.006,rim)
    for s in (-1,1):
        bar((-.657,s*.058,.72),(-.505,s*.057,.346),.005,rim)
        bar((-.376,s*.058,.72),(-.505,s*.057,.346),.005,rim)
        bar((-.375,s*.052,.726),(-.177,s*.016,.701),.005,rim)
    for x,z,r in [(-.51,.338,.043),(-.03,.309,.09)]: hoop(x,-.052,z,r,.0067,alloy)
    bar((-.51,-.052,.38),(-.03,-.052,.398),.006,alloy)
    bar((-.51,-.052,.295),(-.03,-.052,.22),.005,alloy)
    f.tube([(-.535,-.056,.377),(-.41,-.056,.393),(-.043,-.056,.414),(.020,-.056,.409),(.059,-.056,.381)],.012,paint)
    for s in (-1,1):
        end=(-.03+s*.122,s*.071,.309+s*.066)
        bar((-.03,s*.059,.309),end,.010,steel)
        bar(end,(end[0],s*.143,end[2]),.017,rubber)
        bar((end[0]-.014,s*.102,end[2]),(end[0]-.014,s*.132,end[2]),.006,amber)
    f.tube([(-.14,.047,.303),(-.21,.075,.199),(-.279,.169,.017),(-.30,.184,.013)],.0075,steel)
    bar((-.685,0,.705),(-.70,0,.705),.023,red)
    bar((.49,0,.755),(.507,0,.755),.023,m["Lamp"])
    return f


def add_bicycles():
    sc=bpy.context.scene
    if sc.collection.children.get(GROUP):
        return sc.collection.children[GROUP]
    collection=bpy.data.collections.new(GROUP)
    sc.collection.children.link(collection)
    palette=[("Tyre","242628",0,.82),("Graphite","333c40",.58,.38),("Steel","8e9694",.85,.34),
             ("Rim","c0c5bf",.86,.24),("Sidewall","655b49",.12,.59),("Saddle","48372e",.02,.53),
             ("Amber","e99e3a",.18,.27),("Red","ba3226",.22,.28),("Lamp","e3d8b9",.25,.23),
             ("Lagoon","368d88",.48,.30),("Honey","d3a149",.5,.34),("Oxblood","813e3e",.5,.32)]
    m={name:finish(name,col,metal,rough) for name,col,metal,rough in palette}
    for color,x,y,angle in [("Lagoon",-12.34,-15.56,48),("Honey",-11.23,-15.37,69),("Oxblood",-10.14,-15.43,60)]:
        bicycle(m,m[color]).install("Street | step-through · "+color,collection,(x,y,.14),angle)
    f=Fabrication()
    for x in (-12.74,-11.66,-10.59,-9.53):
        path=[(x,-15.92,.145),(x,-15.92,.705)]
        for i in range(1,9):
            a=math.pi*i/16
            path.append((x,-15.80-.12*math.cos(a),.705+.12*math.sin(a)))
        path.append((x,-15.23,.825))
        for i in range(1,9):
            a=math.pi*i/16;path.append((x,-15.23+.12*math.sin(a),.705+.12*math.cos(a)))
        path.append((x,-15.11,.145))
        f.tube(path,.024,m["Steel"],12)
        for y in (-15.92,-15.11):
            f.rounded([(x,y,.14,.064,.064),(x,y,.15,.064,.064),(x,y,.159,.052,.052)],m["Graphite"])
    f.install("Street | bent stainless stands",collection,(0,0,0),0)
    return collection
