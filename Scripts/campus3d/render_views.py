"""Run with Blender -b Zhili-studio.blend -P render_views.py to regenerate the three photographs."""
import sys
from pathlib import Path
import bpy
sys.path.insert(0,str(Path(__file__).resolve().parent))
from zhili_studio import evening

scene=bpy.context.scene
folder=Path(bpy.data.filepath).parent
preferences=bpy.context.preferences.addons["cycles"].preferences
for backend in ["OPTIX","CUDA","METAL","HIP"]:
    try:
        preferences.compute_device_type=backend
        preferences.refresh_devices()
        if any(d.type==backend for d in preferences.devices):
            for device in preferences.devices:device.use=device.type==backend
            scene.cycles.device="GPU"
            break
    except (TypeError,RuntimeError):
        continue
for name,size,filename in [
    ("02 | C entrance photograph",(1440,632),"C-entry.png"),
    ("01 | Courtyard",(1440,880),"C-court.png"),
    ("03 | After class",(1440,880),"C-evening.png")]:
    if filename=="C-evening.png":evening(scene)
    scene.camera=bpy.data.objects[name]
    scene.render.resolution_x,scene.render.resolution_y=size
    scene.cycles.samples=40
    scene.render.filepath=str(folder/filename)
    bpy.ops.render.render(write_still=True)
