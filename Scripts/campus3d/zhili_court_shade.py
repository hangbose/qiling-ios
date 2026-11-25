"""Bake a linear ground-irradiance multiplier for the realtime street camera."""
import math
import struct
import zlib
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree


def bake(scene, destination, width=736, height=576):
    points, faces = [], []
    for ob in scene.objects:
        if ob.type != "MESH" or not ob.name.startswith((
            "C |", "L1 |", "L2 |", "C loggia |", "C courtyard |",
            "Planting", "Street | step-through", "Street | bent stainless",
        )):
            continue
        mesh=ob.data
        start=len(points)
        points.extend(ob.matrix_world @ v.co for v in mesh.vertices)
        faces.extend(tuple(start+i for i in p.vertices) for p in mesh.polygons)
    bvh=BVHTree.FromPolygons(points,faces)
    sky=[Vector((0,0,1))]
    for ring,z in ((5,.77),(8,.42)):
        r=math.sqrt(1-z*z)
        sky.extend(Vector((math.cos((i+.23)*math.tau/ring)*r,
                           math.sin((i+.23)*math.tau/ring)*r,z)) for i in range(ring))
    sun=[Vector((52+dx,-68+dy,51)).normalized() for dx,dy in ((-2,-2),(-2,2),(2,-2),(2,2))]
    # Row zero in the PNG is north (+Blender Y). TextureLoader flips it for bottom-left UVs.
    rows=bytearray()
    lo,hi=255,0
    for row in range(height):
        y=36-(row+.5)*72/height
        rows.append(0)
        for col in range(width):
            x=-46+(col+.5)*92/width
            z=.30 if (-34<x<-12 and -26.5<y<-17.5) or (-7.5<x<11.5 and -27<y<-17) else .18
            start=Vector((x,y,z))
            blockage=0.
            for ray in sky:
                d=bvh.ray_cast(start,ray,27)[3]
                if d is not None:
                    blockage+=1/(1+.067*d)
            shade=sum(bvh.ray_cast(start,d,120)[3] is not None for d in sun)/len(sun)
            v=round(255*max(.55,1-.42*blockage/len(sky)-.22*shade))
            lo=min(v,lo);hi=max(v,hi);rows.append(v)
    def chunk(kind, data):
        return struct.pack(">I",len(data))+kind+data+struct.pack(">I",zlib.crc32(kind+data))
    Path(destination).write_bytes(b"\x89PNG\r\n\x1a\n"+
        chunk(b"IHDR",struct.pack(">2I5B",width,height,8,0,0,0,0))+
        chunk(b"IDAT",zlib.compress(rows,9))+chunk(b"IEND",b""))
    return {"width":width,"height":height,"range":[lo,hi]}
