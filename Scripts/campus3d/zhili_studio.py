"""Editable architectural lighting rig; preview renders use the same exterior mesh as the game."""
import math
from pathlib import Path
import bpy
from mathutils import Vector

def camera(scene,name,pos,look,lens,shift=0):
    lensdata=bpy.data.cameras.new(name);lensdata.lens=lens;lensdata.clip_end=600;lensdata.shift_y=shift
    obj=bpy.data.objects.new(name,lensdata);scene.collection.objects.link(obj)
    obj.location=pos;obj.rotation_euler=(Vector(look)-Vector(pos)).to_track_quat("-Z","Y").to_euler()
    return obj

def material_finish():
    for mat in bpy.data.materials:
        if not mat.use_nodes:continue
        shader=next((n for n in mat.node_tree.nodes if n.type=="BSDF_PRINCIPLED"),None)
        if not shader:continue
        stone=mat.name in {"granite","granite2","ashlar","ashlar2","reveal","porcelain","paver1","paver2","paver3","meadow","chalkwhite","soffit","kerb"}
        if mat.name in {"pane1","pane2","pane3","pane4"}:
            shader.inputs["Transmission Weight"].default_value=.48
            shader.inputs["Metallic"].default_value=.20
            shader.inputs["Roughness"].default_value=.115
            shader.inputs["IOR"].default_value=1.50
            shader.inputs["Coat Weight"].default_value=.40
        if not stone: continue
        tree=mat.node_tree;nodes=tree.nodes;links=tree.links
        coord=nodes.new("ShaderNodeTexCoord")
        noise=nodes.new("ShaderNodeTexNoise");noise.inputs["Scale"].default_value=.58
        noise.inputs["Detail"].default_value=5;noise.inputs["Roughness"].default_value=.72
        links.new(coord.outputs["Object"],noise.inputs["Vector"])
        ramp=nodes.new("ShaderNodeValToRGB");base=mat.diffuse_color[:3]
        ramp.color_ramp.elements[0].color=(*[v*(.68 if mat.name=="meadow" else .85) for v in base],1)
        ramp.color_ramp.elements[1].color=(*[min(1,v*1.08) for v in base],1)
        links.new(noise.outputs["Fac"],ramp.inputs["Fac"]);links.new(ramp.outputs["Color"],shader.inputs["Base Color"])
        grit=nodes.new("ShaderNodeTexNoise");grit.inputs["Scale"].default_value=70
        links.new(coord.outputs["Object"],grit.inputs["Vector"])
        bump=nodes.new("ShaderNodeBump");bump.inputs["Strength"].default_value=.16;bump.inputs["Distance"].default_value=.011
        links.new(grit.outputs["Fac"],bump.inputs["Height"]);links.new(bump.outputs["Normal"],shader.inputs["Normal"])
    for ob in bpy.context.scene.objects:
        if ob.type!="MESH" or any(n in ob.name for n in ("Planting","Paving","Lettering")):continue
        bevel=ob.modifiers.new("Edge catches | 14 mm","BEVEL");bevel.width=.014;bevel.segments=2;bevel.limit_method="ANGLE"
        bevel.harden_normals=True
        normal=ob.modifiers.new("Panel normals","WEIGHTED_NORMAL");normal.keep_sharp=True

def prepare(folder):
    scene=bpy.context.scene;scene.name="Zhili | Entrance court"
    material_finish()
    scene.render.engine="CYCLES";scene.cycles.samples=24;scene.cycles.use_denoising=True
    scene.cycles.max_bounces=5
    world=bpy.data.worlds.new("Coastal daylight");scene.world=world;world.use_nodes=True
    tree=world.node_tree;bg=next(n for n in tree.nodes if n.type=="BACKGROUND")
    sky=tree.nodes.new("ShaderNodeTexEnvironment")
    sky.image=bpy.data.images.load(str(Path(__file__).with_name("coastal-sky.hdr")))
    sky.image.pack()
    tree.links.new(sky.outputs[0],bg.inputs["Color"]);bg.inputs["Strength"].default_value=.45
    sunlight=bpy.data.lights.new("Late afternoon","SUN");sunlight.energy=3.4;sunlight.color=(1,.89,.73);sunlight.angle=.055
    sun=bpy.data.objects.new("Sun from front west",sunlight);scene.collection.objects.link(sun)
    sun.rotation_euler=Vector((.63,.78,-.88)).to_track_quat("-Z","Y").to_euler()
    ground=bpy.data.materials.new("Surround | stone");ground.diffuse_color=(.40,.44,.41,1)
    bpy.ops.mesh.primitive_plane_add(size=1800,location=(0,0,-1.03))
    bpy.context.object.name="Surround | render only";bpy.context.object.data.materials.append(ground)
    # Neutral high-rise context visible through gaps in the official street photograph.
    # The background is kept out of the game asset and of the building attribution.
    for idx,(x,y,w,d,h) in enumerate([(-37,81,13,10,42),(-19,94,14,12,51),(24,111,14,14,47),(-48,-66,19,18,36),(53,-62,20,18,30)]):
        def cube(name,loc,scale,mat):
            bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.dimensions=scale;o.data.materials.append(bpy.data.materials[mat])
        cube("Context silhouette",(x,y,h/2),(w,d,h),"horizon")
        for k in range(1,int(h/2.45)):cube("Context slab",(x,y,k*2.45),(w+.3,d+.3,.14),"reveal")
        for c in range(1,int(w/1.5)):
            cube("Context mullion",(x-w*.5+c*1.5,y-d*.5-.06,h*.5),(.12,.16,h),"granite2")
    scene.render.resolution_percentage=100;scene.render.image_settings.file_format="PNG"
    scene.view_settings.view_transform="AgX";scene.view_settings.look="AgX - Medium High Contrast"
    scene.view_settings.exposure=-.3
    camera(scene,"02 | C entrance photograph",(.15,-43,3.35),(.55,-2,3.35),23,.073)
    camera(scene,"03 | After class",(43,-49,4.8),(3,5,4.8),22,.17)
    scene.camera=camera(scene,"01 | Courtyard",(-34,-87,8),(2,5,8),32,.15)
    scene.render.resolution_x=1440;scene.render.resolution_y=880
    scene.render.filepath="//Zhili-courtyard.png"
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(Path(folder)/"Zhili-studio.blend"),compress=True)

def evening(scene):
    # A second photographic study of the identical geometry, with the public stairs lit.
    tree=scene.world.node_tree
    bg=next(n for n in tree.nodes if n.type=="BACKGROUND")
    sky=next(n for n in tree.nodes if n.type=="TEX_ENVIRONMENT")
    tint=tree.nodes.new("ShaderNodeMixRGB");tint.blend_type="MULTIPLY";tint.inputs[0].default_value=.85
    tint.inputs[2].default_value=(.25,.44,.83,1)
    tree.links.new(sky.outputs[0],tint.inputs[1]);tree.links.new(tint.outputs[0],bg.inputs["Color"])
    bg.inputs["Strength"].default_value=.26
    bpy.data.lights["Late afternoon"].energy=.18
    for key,strength in [("lit",2.5),("pane1",.03),("pane3",.18)]:
        shader=bpy.data.materials[key].node_tree.nodes.get("Principled BSDF")
        shader.inputs["Emission Color"].default_value=(1,.67,.36,1)
        shader.inputs["Emission Strength"].default_value=strength
    for i,(x,y,z,size,power) in enumerate([(-17,-10,5.45,4,310),(-5,-10,5.45,4,340),(8,-10,5.45,4,340),(17,-10,5.45,4,300),
                                          (29,-1.8,8.42,6,540),(-4.5,-3.5,5.35,4,290),(35,-11,4,3,230)]):
        data=bpy.data.lights.new("Public downlight","AREA");data.energy=power;data.shape="DISK";data.size=size;data.color=(1,.66,.35)
        light=bpy.data.objects.new("Courtyard downlight "+str(i),data);scene.collection.objects.link(light);light.location=(x,y,z)
    for i,x in enumerate((-25,-12,0,13,25)):
        data=bpy.data.lights.new("Warm lawn lamp","POINT");data.energy=26;data.color=(1,.77,.44);data.shadow_soft_size=.22
        light=bpy.data.objects.new("Lawn lamp "+str(i),data);scene.collection.objects.link(light);light.location=(x,-23.3,.46)
    scene.camera=bpy.data.objects["03 | After class"];scene.view_settings.exposure=.4
