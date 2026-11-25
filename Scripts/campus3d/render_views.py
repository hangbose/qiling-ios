"""Render exterior views from the saved study. Pass -- proof for small daylight drafts."""
import sys
from pathlib import Path
import bpy
sys.path.insert(0,str(Path(__file__).resolve().parent))
from zhili_studio import courtyard_light, evening

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
proof = "--" in sys.argv and "proof" in sys.argv[sys.argv.index("--")+1:]
for name,size,filename in [
    ("02 | C entrance photograph",(1440,632),"C-entry.png"),
    ("01 | Courtyard",(1840,1200),"C-court.png"),
    ("04 | Under the portico",(1560,1040),"C-shelter.png"),
    ("03 | After class",(1440,880),"C-evening.png")]:
    if filename=="C-court.png":courtyard_light(scene)
    if filename=="C-evening.png":
        if proof:continue
        evening(scene)
    scene.camera=bpy.data.objects[name]
    scene.render.resolution_x,scene.render.resolution_y=size
    scene.render.resolution_percentage=39 if proof else 100
    scene.cycles.samples=10 if proof else 72
    scene.cycles.adaptive_threshold=.055 if proof else .018
    scene.render.filepath=str(folder/(("proof-" if proof else "")+filename))
    bpy.ops.render.render(write_still=True)
