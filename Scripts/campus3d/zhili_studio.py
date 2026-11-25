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
        # Keep the game finish. In close-ups add capillary staining only where
        # the column meets the paving; do not uniformly dirty the entire facade.
        if mat.name in {"granite","granite2"} and shader.inputs["Base Color"].is_linked:
            tile=shader.inputs["Base Color"].links[0].from_socket
            geom=nodes.new("ShaderNodeNewGeometry")
            xyz=nodes.new("ShaderNodeSeparateXYZ");links.new(geom.outputs["Position"],xyz.inputs[0])
            uneven=nodes.new("ShaderNodeMath");uneven.operation="MULTIPLY_ADD"
            links.new(noise.outputs["Fac"],uneven.inputs[0]);uneven.inputs[1].default_value=.38
            uneven.inputs[2].default_value=-.18
            height=nodes.new("ShaderNodeMath");height.operation="ADD"
            links.new(xyz.outputs["Z"],height.inputs[0]);links.new(uneven.outputs[0],height.inputs[1])
            mask=nodes.new("ShaderNodeMapRange");mask.clamp=True
            links.new(height.outputs[0],mask.inputs[0])
            for name,value in [("From Min",.22),("From Max",.95),("To Min",.73),("To Max",0)]:
                mask.inputs[name].default_value=value
            stain=nodes.new("ShaderNodeMixRGB");stain.blend_type="MULTIPLY"
            links.new(mask.outputs[0],stain.inputs[0]);links.new(tile,stain.inputs[1])
            stain.inputs[2].default_value=(.47,.52,.44,1)
            links.new(stain.outputs[0],shader.inputs["Base Color"])
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
    from zhili_garden import grow_lawns
    grow_lawns(scene)
    scene.render.engine="CYCLES";scene.cycles.samples=24;scene.cycles.use_denoising=True
    scene.cycles.max_bounces=5
    world=bpy.data.worlds.new("Coastal daylight");scene.world=world;world.use_nodes=True
    tree=world.node_tree;bg=next(n for n in tree.nodes if n.type=="BACKGROUND")
    sky=tree.nodes.new("ShaderNodeTexEnvironment")
    sky.image=bpy.data.images.load(str(Path(__file__).with_name("coastal-sky.hdr")))
    sky.image.pack()
    # The reference facade is photographed in luminous, humid daylight.
    # Lighten the horizon while retaining directional HDR variation in glazing.
    haze=tree.nodes.new("ShaderNodeMixRGB");haze.name="Maritime haze";haze.inputs[0].default_value=.64
    haze.inputs[2].default_value=(.91,.96,1.,1)
    tree.links.new(sky.outputs["Color"],haze.inputs[1]);tree.links.new(haze.outputs[0],bg.inputs["Color"])
    bg.inputs["Strength"].default_value=1.05
    sunlight=bpy.data.lights.new("Late afternoon","SUN");sunlight.energy=1.60;sunlight.color=(1,.935,.825);sunlight.angle=.20
    sun=bpy.data.objects.new("Sun from front west",sunlight);scene.collection.objects.link(sun)
    sun.rotation_euler=Vector((.63,.78,-.88)).to_track_quat("-Z","Y").to_euler()
    # The curb of the game board is useful in orbit view. In an eye-level
    # photograph the paving continues onto campus, including beyond the crop.
    bpy.ops.mesh.primitive_plane_add(size=1200,location=(0,0,.078))
    surround=bpy.context.object;surround.name="Surround | adjoining paving"
    surround.data.materials.append(bpy.data.materials["paver3"])
    for uv in surround.data.uv_layers.active.data:uv.uv*=665.
    canopy=[o for o in scene.objects if o.name.startswith("Planting | canopy (") and o.type=="MESH"]
    for x,y,scale,angle in [(-101,-9,1.38,.15),(-98,38,1.55,-.20),(114,54,1.4,.2),(18,95,1.45,-.12)]:
        for source in canopy:
            copy=source.copy();copy.name="Distant canopy | "+source.name
            scene.collection.objects.link(copy);copy.location=(x,y,0)
            copy.scale=(scale,)*3;copy.rotation_euler.z=angle
    # One crown at the edge of the arrival camera breaks up the blank sky.
    # Its trunk is outside the photographed C-entry elevation.
    for source in canopy:
        if not source.name.startswith("Planting | canopy (-38,-21)"):continue
        specimen=source.copy();specimen.name="Walkway tree | "+source.name
        scene.collection.objects.link(specimen);specimen.scale=(1.42,1.42,1.42)
        specimen.location=(7.3+38*1.42,-46.8+21*1.42,0)
    # Neutral high-rise context visible through gaps in the official street photograph.
    # The background is kept out of the game asset and of the building attribution.
    for idx,(x,y,w,d,h) in enumerate([(-38,63,13,13,43),(-19,76,14,13,50),(24,111,14,14,47),(-48,-66,19,18,36),(53,-62,20,18,30)]):
        def cube(name,loc,scale,mat):
            bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.dimensions=scale;o.data.materials.append(bpy.data.materials[mat])
        cube("Context silhouette",(x,y,h/2),(w,d,h),"pane3")
        for k in range(1,int(h/2.45)):cube("Context slab",(x,y,k*2.45),(w+.62,d+.62,.27),"reveal")
        for c in range(1,int(w/1.5)):
            cube("Context mullion",(x-w*.5+c*1.5,y-d*.5-.06,h*.5),(.12,.16,h),"granite2")
    scene.render.resolution_percentage=100;scene.render.image_settings.file_format="PNG"
    scene.view_settings.view_transform="AgX";scene.view_settings.look="AgX - Medium High Contrast"
    scene.view_settings.exposure=.13
    camera(scene,"02 | C entrance photograph",(.04,-42.5,3.30),(.04,0,3.30),23,.124)
    camera(scene,"03 | After class",(43,-49,4.8),(3,5,4.8),22,.17)
    scene.camera=camera(scene,"01 | Courtyard",(19,-54,1.72),(0,6,4.5),22.5,.19)
    camera(scene,"04 | Under the portico",(-17.1,-11,1.6),(9,-4.5,2.3),22,.04)
    scene.render.resolution_x=1440;scene.render.resolution_y=880
    scene.render.filepath="//Zhili-courtyard.png"
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(Path(folder)/"Zhili-studio.blend"),compress=True)

def courtyard_light(scene):
    # Breaks in the clouds after a shower. Gloss collects in islands of the
    # paving, while the joints remain rough and the upper facade stays dry.
    tree=scene.world.node_tree
    haze=tree.nodes["Maritime haze"];haze.inputs[0].default_value=.27
    bg=next(n for n in tree.nodes if n.type=="BACKGROUND");bg.inputs["Strength"].default_value=.88
    sun=bpy.data.lights["Late afternoon"];sun.energy=3.35;sun.color=(1.,.81,.61);sun.angle=.06
    bpy.data.objects["Sun from front west"].rotation_euler=Vector((-.7,.9,-.65)).to_track_quat("-Z","Y").to_euler()
    for name in ("paver1","paver2","paver3","granite","stairrose","stairrose2"):
        material=bpy.data.materials.get(name)
        if not material:continue
        nodes,links=material.node_tree.nodes,material.node_tree.links
        surface=nodes.get("Principled BSDF")
        tex=nodes.new("ShaderNodeTexNoise");tex.inputs["Scale"].default_value=.72;tex.inputs["Detail"].default_value=4.8
        coord=nodes.new("ShaderNodeNewGeometry");links.new(coord.outputs["Position"],tex.inputs["Vector"])
        rough=nodes.new("ShaderNodeValToRGB");e=rough.color_ramp.elements
        e[0].position=.40;e[0].color=(.16,.16,.16,1);e[1].position=.63;e[1].color=(.78,.78,.78,1)
        links.new(tex.outputs["Fac"],rough.inputs[0]);links.new(rough.outputs[0],surface.inputs["Roughness"])
        surface.inputs["Coat Weight"].default_value=.28
        links.new(rough.outputs[0],surface.inputs["Coat Roughness"])

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
