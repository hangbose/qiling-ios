"""Refine only the west entrance hedge in either the studio scene or game GLB."""

import struct
import json
import os
import tempfile
import zlib
from pathlib import Path

import bmesh
import bpy
import numpy as np


COLLECTION = "Street | C portico hedge leaves"
SPECIES_SLOTS = ("laurel", "leafshade", "myrtle", "newleaf")  # Existing palette keys.
PALETTE = [(98,119,72), (66,88,60), (79,103,66), (134,151,87)]


def _leaf_material():
    name = "Zhili hedge / cuticle and pinnate veins"
    mat = bpy.data.materials.get(name)
    if mat and mat.get("has_atlas"):
        return mat
    size = 160
    tile = np.empty((size*2,size*2,3),np.uint8)
    y,x = np.mgrid[0:size,0:size].astype(float)/(size-1)
    rng = np.random.default_rng(60112)
    for i,base in enumerate(PALETTE):
        # Physical geometry supplies the silhouette and central camber. Veins
        # under the cuticle taper toward the tip, without transparency cards.
        v=(y-.5)*2
        mid=.017*np.sin(x*3.1)
        midrib=np.exp(-((v-mid)/(.009+.021*(1-x)))**2)
        lamina=1.5*np.sin(10*x+3*v)+.8*np.sin(11*v+2*x)
        secondary=np.zeros_like(x)
        for j in range(7):
            root=.12+j*.1
            path=x-root-.13*abs(v)**.78-.035*v*v
            secondary+=np.exp(-(path/(.004+.001*j))**2)*np.exp(-abs(v)*1.9)
        shift=(midrib*(18-10*x)+secondary*6+lamina+rng.normal(0,1.35,x.shape)
               -3.8*abs(v)**1.5)
        pixels=np.clip(np.asarray(base)+shift[:,:,None]*np.array([1,.93,.60]),0,255).astype(np.uint8)
        c,r=i%2,1-i//2
        tile[r*size:(r+1)*size,c*size:(c+1)*size]=pixels
    def chunk(tag,body):
        return struct.pack(">I",len(body))+tag+body+struct.pack(">I",zlib.crc32(tag+body))
    raw=b"".join(b"\x00"+row.tobytes() for row in tile)
    png=(b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR",struct.pack(">IIBBBBB",size*2,size*2,8,2,0,0,0))
         +chunk(b"IDAT",zlib.compress(raw,8))+chunk(b"IEND",b""))
    with tempfile.TemporaryDirectory() as temp:
        path=Path(temp)/"hedge_leaf_atlas.png"
        path.write_bytes(png)
        image=bpy.data.images.load(str(path))
        image.name="Zhili hedge | leaf cuticle atlas"
        image.pack()
        image.filepath="//hedge_leaf_atlas.png"
    mat=mat or bpy.data.materials.new(name)
    mat.use_nodes=True
    mat.use_backface_culling=False
    mat.diffuse_color=(.15,.23,.095,1)
    shader=next(n for n in mat.node_tree.nodes if n.type=="BSDF_PRINCIPLED")
    shader.inputs["Roughness"].default_value=.67
    shader.inputs["Specular IOR Level"].default_value=.28
    tex=mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image=image
    mat.node_tree.links.new(tex.outputs["Color"],shader.inputs["Base Color"])
    mat["has_atlas"]=True
    return mat


def _recognize(obj):
    """Recover blade roots/tips despite glTF splitting coincident hard normals."""
    mesh=obj.data
    coords=np.empty(len(mesh.vertices)*3,np.float32)
    mesh.vertices.foreach_get("co",coords)
    coords=coords.reshape(-1,3)
    if len(mesh.polygons)%4 or len(mesh.loops)!=len(mesh.polygons)*3:
        raise ValueError("Unexpected hedge topology on "+obj.name)
    idx=np.empty(len(mesh.loops),np.int32)
    mesh.loops.foreach_get("vertex_index",idx)
    ids=idx.reshape(-1,4,3)
    return _mask_corners(ids,coords[ids],np.asarray(obj.matrix_world,dtype=float))


def _mask_corners(ids,corners,transform):
    # Each blade was a 4-face fan; edge joins and its central point identify
    # it even when the exporter duplicated every normal and vertex index.
    fan=(np.abs(corners[:,:,1]-np.roll(corners[:,:,0],-1,axis=1)).max(axis=(1,2))<.0001)
    fan&=(np.abs(corners[:,:,2]-corners[:,0:1,2]).max(axis=(1,2))<.0001)
    def world(points):
        return points @ transform[:3,:3].T + transform[:3,3]
    roots=world(corners[:,0,0])
    tips=world(corners[:,1,1])
    center=(roots+tips)*.5
    length=np.linalg.norm(tips-roots,axis=1)
    mask=(fan & (center[:,0]>-29.60) & (center[:,0]<-14.4)
          & (center[:,1]>-17.16) & (center[:,1]<-14.64)
          & (center[:,2]>.28) & (center[:,2]<1.37) & (length>.078))
    return ids[mask], roots[mask], tips[mask], world(corners[mask,0,1]), world(corners[mask,2,1])


def _blades(roots,tips,left,right,slot):
    count=len(roots)
    # Using coordinates rather than imported vertex IDs preserves variation
    # across a glTF export/import even when vertices have been split at normals.
    seed=np.sin(np.floor(roots*1000) @ [13.189,23.217,9.134])*17232.372
    phase=seed-np.floor(seed)
    bend=np.sin(phase*18.4)
    length=np.linalg.norm(tips-roots,axis=1)
    direction=tips-roots
    normal=direction.copy()
    normal[:,0]=-direction[:,1]
    normal[:,1]=direction[:,0]
    normal[:,2]=0
    normal/=np.linalg.norm(normal,axis=1)[:,None]
    half=np.linalg.norm(left-right,axis=1)*(.37+.042*phase)
    coords=np.empty((count,9,3),float)
    # The gradual shoulders and offset drip tip catch small glints as one
    # continuous shape, with a soft asymmetric twist along the midrib.
    sections=[(.025,0),(.18,-.63),(.39,-1),(.72,-.68),(.97,0),
              (.72,.61),(.39,.96),(.18,.62),(.44,0)]
    uv=np.empty((count,9,2),np.float32)
    for j,(t,side) in enumerate(sections):
        u=t+(.011*bend*abs(side))
        width=half*side*(1+.09*np.sin(phase*22+side))*np.ones(count)
        spine=roots+direction*u[:,None]
        spine+=normal*(length*np.sin(t*np.pi)*.053*bend+length*t*t*.029*np.sin(phase*20))[:,None]
        spine[:,2]+=length*(.075*np.sin(t*np.pi)+.022*bend*np.sin(2*t*np.pi)-.023*t**5)
        edge=spine+normal*width[:,None]
        # Upper-face normal points out toward daylight. Tips curl downward as
        # the blade thins; mature shoulders sag a little under their own weight.
        edge[:,2]+=width*(.17*np.sin(phase*16)+(t-.4)*.25)-abs(width)*(.135+.065*phase)
        coords[:,j]=edge
        uv[:,j,0]=(slot%2+.025+u*.95)/2
        uv[:,j,1]=(slot//2+.5+side*.45)/2
    idx=np.arange(count,dtype=np.int32)[:,None,None]*9
    # Order traverses the right rim to the drip tip, then back along the left.
    faces=idx+np.array([(i,(i+1)%8,8) for i in range(8)],np.int32)[None,:,:]
    return coords.reshape(-1,3),faces.reshape(-1,3),uv.reshape(-1,2)


def refine(scene):
    """Replace only the portico hedge; meadow grass and trees keep their meshes.

    Call once in the source scene and once in a fresh game-GLB import before
    exporting. The original object/mesh names are shared by both pipelines.
    """
    previous=scene.collection.children.get(COLLECTION)
    if previous:
        return {"leaves":previous["leaf_count"],"net_triangles":previous["net_triangles"]}
    batches=[]
    replacements=[]
    total=0
    try:
        for slot,key in enumerate(SPECIES_SLOTS):
            matches=[obj for obj in scene.objects if obj.type=="MESH"
                     and obj.name.split(".")[0]=="Planting-"+key]
            if len(matches)!=1:
                raise ValueError(f"Expected one Planting-{key} mesh in {scene.name}; got {len(matches)}")
            obj=matches[0]
            ids,roots,tips,left,right=_recognize(obj)
            if not len(ids):
                raise ValueError("West entrance garden blades missing in "+obj.name)
            coords,faces,uv=_blades(roots,tips,left,right,slot)
            batches.append((coords,faces+total*9,uv))
            total+=len(roots)
            replacement=obj.data.copy()
            replacements.append((obj,obj.data,replacement))
            bm=bmesh.new()
            try:
                bm.from_mesh(replacement)
                bm.verts.ensure_lookup_table()
                bmesh.ops.delete(bm,geom=[bm.verts[int(i)] for i in np.unique(ids)],context="VERTS")
                bm.to_mesh(replacement)
                replacement.update()
            finally:
                bm.free()
        positions=np.concatenate([b[0] for b in batches]).astype(np.float32)
        indices=np.concatenate([b[1] for b in batches]).astype(np.int32)
        uv=np.concatenate([b[2] for b in batches])
        material=_leaf_material()
        mesh=bpy.data.meshes.new("C entrance hedge | curved laminae")
        mesh.vertices.add(len(positions))
        mesh.vertices.foreach_set("co",positions.ravel())
        mesh.loops.add(indices.size)
        mesh.loops.foreach_set("vertex_index",indices.ravel())
        mesh.polygons.add(len(indices))
        mesh.polygons.foreach_set("loop_start",np.arange(0,indices.size,3,dtype=np.int32))
        mesh.polygons.foreach_set("use_smooth",np.ones(len(indices),dtype=bool))
        mesh.materials.append(material)
        mesh.update(calc_edges=True)
        mesh.uv_layers.new(name="Leaf atlas").data.foreach_set("uv",uv[indices].ravel())
        collection=bpy.data.collections.new(COLLECTION)
        scene.collection.children.link(collection)
        collection.objects.link(bpy.data.objects.new("C courtyard | curved hedge foliage",mesh))
        collection["leaf_count"]=total
        collection["net_triangles"]=total*4
        for obj,old,replacement in replacements:
            obj.data=replacement
            if not old.users:
                name=old.name
                bpy.data.meshes.remove(old)
                replacement.name=name
        return {"leaves":total,"net_triangles":total*4}
    except Exception:
        for _,_,replacement in replacements:
            if not replacement.users:
                bpy.data.meshes.remove(replacement)
        raise


def refine_glb(source,destination):
    """Patch the existing self-contained Zhili GLB without re-encoding other meshes.

    The original is a flat set of single-primitive nodes with dedicated tightly
    packed buffer views. Validate those preconditions before writing the result.
    """
    raw=Path(source).read_bytes()
    magic,version,total,json_size,kind=struct.unpack_from("<4s4I",raw)
    if (magic,version,total,kind)!=(b"glTF",2,len(raw),0x4e4f534a):
        raise ValueError("Expected a complete glTF 2 binary scene")
    doc=json.loads(raw[20:20+json_size])
    offset=20+json_size
    binary_size,binary_kind=struct.unpack_from("<2I",raw,offset)
    if len(doc["buffers"])!=1 or binary_kind!=0x004e4942:
        raise ValueError("The campus must use one embedded binary buffer")
    binary=memoryview(raw)[offset+8:offset+8+binary_size]
    views=doc["bufferViews"]
    payload=[binary[v.get("byteOffset",0):v.get("byteOffset",0)+v["byteLength"]] for v in views]
    accessors=doc["accessors"]
    types={5121:"u1",5123:"<u2",5125:"<u4",5126:"<f4"}
    dimensions={"SCALAR":1,"VEC2":2,"VEC3":3,"VEC4":4}
    def read(index):
        acc=accessors[index]; vi=acc["bufferView"]
        if acc.get("byteOffset",0) or "sparse" in acc or "byteStride" in views[vi]:
            raise ValueError("A dedicated packed hedge accessor is required")
        return np.frombuffer(payload[vi],types[acc["componentType"]]).reshape(acc["count"],dimensions[acc["type"]])
    def set_array(index,array):
        acc=accessors[index]
        acc["count"]=len(array)
        for bound,op in [("min",np.min),("max",np.max)]:
            if bound in acc:
                acc[bound]=op(array,axis=0).tolist()
        payload[acc["bufferView"]]=array.tobytes()
    def add_view(data,target=None):
        view={"buffer":0,"byteLength":len(data)}
        if target is not None:
            view["target"]=target
        views.append(view); payload.append(data)
        return len(views)-1
    def add_accessor(array,component,kind,target,bounds=False):
        array=np.ascontiguousarray(array,dtype=types[component])
        acc={"bufferView":add_view(array.tobytes(),target),"componentType":component,
             "count":len(array),"type":kind}
        if bounds:
            acc.update(min=array.min(axis=0).tolist(),max=array.max(axis=0).tolist())
        accessors.append(acc)
        return len(accessors)-1

    nodes=doc["nodes"]
    if any(n.get("name")=="C courtyard | curved hedge foliage" for n in nodes):
        raise ValueError("This input already contains the refined hedge")
    parented={child for n in nodes for child in n.get("children",[])}
    mat_index=len(doc["materials"])
    hedge_primitives=[]
    count=0
    root_indices=[]
    preserved=set(range(len(views)))
    for slot,key in enumerate(SPECIES_SLOTS):
        ni=next(i for i,n in enumerate(nodes) if n.get("name")=="Planting-"+key)
        node=nodes[ni]
        if ni in parented or any(t in node for t in ("matrix","translation","rotation","scale")):
            raise ValueError("The hedge must be in world coordinates")
        root_indices.append(ni)
        (prim,)=doc["meshes"][node["mesh"]]["primitives"]
        attrs=prim["attributes"]
        originals={k:read(a) for k,a in attrs.items()}
        positions=originals["POSITION"]
        old_indices=read(prim["indices"])
        ids=old_indices.reshape(-1,4,3)
        blender_coords=positions[:,[0,2,1]].copy()
        blender_coords[:,1]*=-1
        selected,roots,tips,left,right=_mask_corners(ids,blender_coords[ids],np.eye(4))
        if not len(roots):
            raise ValueError("No entrance leaves found in "+node["name"])
        # Vertices at the material boundary are distinct islands. Preserve each
        # untouched triangle's precise positions, normals and any future UVs.
        take=np.ones(len(positions),dtype=bool)
        take[np.unique(selected)]=False
        per_corner=take[ids]
        if (per_corner.any(axis=(1,2))!=per_corner.all(axis=(1,2))).any():
            raise ValueError("A hedge blade shared vertices with its neighbour")
        keep=per_corner.all(axis=(1,2))
        remap=np.cumsum(take,dtype=np.int32)-1
        for k,index in attrs.items():
            preserved.discard(accessors[index]["bufferView"])
            set_array(index,originals[k][take])
        index=prim["indices"]
        preserved.discard(accessors[index]["bufferView"])
        set_array(index,remap[ids[keep]].reshape(-1,1).astype(old_indices.dtype))
        coords,faces,uv=_blades(roots,tips,left,right,slot)
        pos=coords[:,[0,2,1]].copy()
        pos[:,2]*=-1
        uv[:,1]=1-uv[:,1]
        area=np.cross(pos[faces[:,1]]-pos[faces[:,0]],pos[faces[:,2]]-pos[faces[:,0]])
        normals=np.zeros_like(pos)
        for corner in range(3):
            np.add.at(normals,faces[:,corner],area)
        normals/=np.maximum(np.linalg.norm(normals,axis=1)[:,None],1e-12)
        hedge_primitives.append({
            "attributes":{"POSITION":add_accessor(pos,5126,"VEC3",34962,True),
                          "NORMAL":add_accessor(normals,5126,"VEC3",34962),
                          "TEXCOORD_0":add_accessor(uv,5126,"VEC2",34962)},
            "indices":add_accessor(faces.reshape(-1,1),5123 if len(coords)<=65535 else 5125,"SCALAR",34963),
            "material":mat_index})
        count+=len(roots)
    material=_leaf_material()
    image=next(n.image for n in material.node_tree.nodes if n.type=="TEX_IMAGE")
    im=len(doc["images"])
    doc["images"].append({"bufferView":add_view(image.packed_file.data),"mimeType":"image/png","name":image.name})
    texture=len(doc["textures"])
    doc["textures"].append({"source":im})
    doc["materials"].append({"name":material.name,"doubleSided":True,
                             "pbrMetallicRoughness":{"baseColorTexture":{"index":texture},
                                                     "metallicFactor":0.0,"roughnessFactor":.67}})
    foliage="C courtyard | curved hedge foliage"
    mi=len(doc["meshes"])
    doc["meshes"].append({"name":foliage,"primitives":hedge_primitives})
    ni=len(nodes); nodes.append({"name":foliage,"mesh":mi})
    visible=False
    for s in doc["scenes"]:
        if all(i in s["nodes"] for i in root_indices):
            s["nodes"].append(ni)
            visible=True
    if not visible:
        raise ValueError("No scene has all the original hedge objects")
    # Untouched views keep their original bytes, including AO, artwork, material
    # images and every other mesh attribute. Only buffer offsets may change.
    output=bytearray()
    for i,(view,data) in enumerate(zip(views,payload)):
        if i in preserved and not isinstance(data,memoryview):
            raise ValueError("An unrelated GLB payload was modified")
        output.extend(b"\0"*((-len(output))%4))
        view["byteOffset"]=len(output); view["byteLength"]=len(data)
        output.extend(data)
    doc["buffers"][0]["byteLength"]=len(output)
    output.extend(b"\0"*((-len(output))%4))
    header=json.dumps(doc,ensure_ascii=False,separators=(",",":")).encode("utf8")
    header+=b" "*((-len(header))%4)
    destination=Path(destination)
    with tempfile.NamedTemporaryFile(dir=destination.parent,suffix=".glb",delete=False) as temp:
        name=temp.name
        try:
            temp.write(struct.pack("<4s4I",b"glTF",2,28+len(header)+len(output),len(header),0x4e4f534a))
            temp.write(header); temp.write(struct.pack("<2I",len(output),0x004e4942)); temp.write(output)
        except Exception:
            temp.close()
            Path(name).unlink(missing_ok=True)
            raise
    os.replace(name,destination)
    return {"leaves":count,"net_triangles":count*4,"preserved_buffer_views":len(preserved),
            "size_bytes":destination.stat().st_size}
