"""Render a fast proof or final stills and navigable probes from the saved scene."""
import sys
from pathlib import Path
import bpy

out, mode = sys.argv[sys.argv.index('--')+1:]
out=Path(out)
s=bpy.data.scenes["致理楼 C · 雨夜连廊"]
bpy.context.window.scene=s
prefs=bpy.context.preferences.addons["cycles"].preferences
for backend in ("OPTIX","CUDA","METAL","HIP","ONEAPI"):
    try:
        prefs.compute_device_type=backend
        prefs.refresh_devices()
        gpu=[d for d in prefs.devices if d.type==backend]
        if gpu:
            for device in prefs.devices:device.use=device in gpu
            s.cycles.device="GPU"
            break
    except (TypeError,RuntimeError):
        continue
views=[
    ("Threshold","threshold",1800,1200,128),
    ("At the notices","notices",1440,960,96),
    ("Pano threshold","pano-0",4096,2048,64),
    ("Pano bench","pano-1",4096,2048,64),
    ("Pano notices","pano-2",4096,2048,64),
]
for name,filename,w,h,samples in views:
    if mode=="proof" and filename!="threshold":continue
    if mode not in ("proof","final") and mode!=filename:continue
    if mode=="proof":w,h,samples,filename=832,554,14,"proof"
    s.camera=s.objects[name]
    s.cycles.samples=samples
    s.cycles.adaptive_threshold=.016 if mode!="proof" else .05
    s.render.resolution_x=w;s.render.resolution_y=h
    s.render.filepath=str(out/(filename+".png"))
    bpy.ops.render.render(write_still=True,scene=s.name)
