"""Author and export the eye-level street layer from the editable Zhili studio."""
from pathlib import Path
import bpy
from zhili_bicycles import add_bicycles, finish
from zhili_street_signs import add_signs
from zhili_street_surface import add_surfaces
from zhili_street_lobby import add_lobby
from zhili_street_leaves import refine
from zhili_treeline import add_backdrop
from zhili_street_turf import add_turf
from zhili_studio import camera


def street_context(scene):
    """Reuse the studio's skyline and make lightweight silhouettes of its distant crowns."""
    name = "Street | Background for the walking camera"
    collection = scene.collection.children.get(name)
    if collection:
        return collection
    collection = bpy.data.collections.new(name)
    scene.collection.children.link(collection)
    palette = {
        "Context silhouette": finish("Distant blue glazing","899da3",.32,.48),
        "Context mullion": finish("Distant uprights","a8b4b1",.25,.56),
        "Context slab": finish("Distant balconies","b9c3bd",.13,.64),
        "Surround": finish("Distant paving","a3a49c",.02,.84),
    }
    for obj in list(scene.objects):
        key = next((k for k in palette if obj.name.startswith(k)),None)
        if key:
            proxy = obj.copy()
            proxy.data = obj.data.copy()
            proxy.data.materials.clear()
            proxy.data.materials.append(palette[key])
        elif obj.name.startswith(("Distant canopy | Planting | canopy (-38,-21)",
                                  "Distant canopy | Planting | canopy (-42,-3)",
                                  "Walkway tree |")):
            proxy = obj.copy()
            mod = proxy.modifiers.new("Street silhouette","DECIMATE")
            mod.ratio = .06 if "bark" not in obj.name else .22
        else:
            continue
        proxy.name = "Game | " + obj.name
        proxy.hide_render = True  # The studio already contains the full resolution original.
        collection.objects.link(proxy)
    collection.hide_viewport = True
    return collection


def build():
    scene=bpy.data.scenes["Zhili | Entrance court"]
    bpy.context.window.scene=scene
    refine(scene)
    groups=[add_bicycles(),add_surfaces(),add_signs(),add_lobby(),add_backdrop(),add_turf(),street_context(scene)]
    for name,eye,target,lens,shift in [
        ("05 | Campus cycle lane",(-17.1,-18.80,1.57),(-11.4,-14.6,1.14),29,.01),
        ("06 | Under the eaves",(-6.4,-18.65,1.57),(-12.0,-14.6,1.24),28,.025),
        ("07 | Gallery noticeboard",(-8.72,1.92,1.58),(-7.84,6.84,1.52),31,.00),
    ]:
        if not scene.objects.get(name):
            camera(scene,name,eye,target,lens,shift)
    scene.camera=scene.objects["05 | Campus cycle lane"]
    scene.render.resolution_x,scene.render.resolution_y=1600,1000
    scene.render.resolution_percentage=100
    return groups


def export(groups, path):
    context=groups[-1]
    context.hide_viewport=False
    try:
        bpy.ops.object.select_all(action="DESELECT")
        for group in groups:
            for obj in group.objects:
                obj.select_set(True)
        bpy.ops.export_scene.gltf(filepath=str(Path(path)),use_selection=True,use_active_scene=True,export_format="GLB",
                                  export_apply=True,export_animations=False,export_cameras=False,
                                  export_lights=False,export_yup=True)
    finally:
        bpy.ops.object.select_all(action="DESELECT")
        context.hide_viewport=True
