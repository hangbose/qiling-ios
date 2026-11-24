"""Resample Cycles panoramas to six rectilinear faces for the offline mobile viewer."""
from pathlib import Path
import sys
import numpy as np
from PIL import Image


def atlas(source, target, size=1024):
    src=np.asarray(Image.open(source).convert("RGB"))
    h,w=src.shape[:2]
    ax=(np.arange(size,dtype=np.float32)+.5)*2/size-1
    x,y=np.meshgrid(ax,ax)
    one=np.ones_like(x)
    faces=[(x,-y,one),(one,-y,-x),(-x,-y,-one),(-one,-y,x),(x,one,y),(x,-one,-y)]
    sheet=Image.new("RGB",(size*3,size*2))
    for i,(a,b,c) in enumerate(faces):
        u=(.5+np.arctan2(a,c)/(2*np.pi))*w-.5
        v=np.clip((.5-np.arcsin(b/np.sqrt(a*a+b*b+c*c))/np.pi)*h-.5,0,h-1)
        iu=np.floor(u).astype(int);iv=np.floor(v).astype(int)
        fu=(u-iu)[:,:,None];fv=(v-iv)[:,:,None]
        upper=src[iv,iu%w]*(1-fu)+src[iv,(iu+1)%w]*fu
        lower=src[np.minimum(iv+1,h-1),iu%w]*(1-fu)+src[np.minimum(iv+1,h-1),(iu+1)%w]*fu
        data=(upper*(1-fv)+lower*fv).round().astype(np.uint8)
        sheet.paste(Image.fromarray(data),((i%3)*size,(i//3)*size))
    sheet.save(target,quality=87,method=6)

if __name__=="__main__":
    source,target=map(Path,sys.argv[1:3])
    for i in range(3):
        atlas(source/f"pano-{i}.png",target/f"corridor-{i}.webp")
    Image.open(source/"threshold.png").convert("RGB").save(target/"corridor-front.webp",quality=89,method=6)
