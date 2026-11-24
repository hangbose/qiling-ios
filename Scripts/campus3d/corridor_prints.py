"""Original printed matter for the architectural study. Run before Blender."""
from pathlib import Path
from math import sin, cos, pi
import random
import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

def prepare(folder):
    folder = Path(folder)
    folder.mkdir(exist_ok=True, parents=True)
    rng = random.Random(8824)
    def font(size, bold=False):
        faces = [Path("C:/Windows/Fonts") / ("msyhbd.ttc" if bold else "msyh.ttc"),
                 Path("/System/Library/Fonts/PingFang.ttc"), Path("/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc")]
        return ImageFont.truetype(str(next(p for p in faces if p.exists())), size)
    paper, blue, ink = "#e4dfcc", "#274453", "#202e2e"
    def new(size, color):
        im = Image.new("RGB", size, color)
        return im, ImageDraw.Draw(im)
    def write(name, im):
        im.save(folder / (name + ".png"), optimize=True)
    def label(d, xy, value, size, fill=ink, bold=False):
        d.text(xy, value, font=font(size, bold), fill=fill)
    def leaf(d, x, y, length, a, color):
        b = length * .23
        def pt(f, offset):
            return x+cos(a)*f-sin(a)*offset, y+sin(a)*f+cos(a)*offset
        pts=[pt(f*length,side*b*sin(pi*f)) for side,ran in [(1,range(12)),(-1,reversed(range(12)))] for i in ran for f in [i/11]]
        d.polygon(pts,fill=color);d.line([pt(0,0),pt(length,0)],fill="#d6cba1",width=2)
    # A two-colour botanical screen print. Line art stays legible through glazing.
    im,d = new((640,900), "#dfd9be")
    d.rectangle((23,22,617,881),outline="#737b67",width=2)
    label(d,(45,36),"荔园物候",83,blue,True); label(d,(51,156),"一场雨之后",33)
    label(d,(52,223),"FIELD NOTES    /    THE LITCHI GARDEN",16)
    d.line((53,266,585,266),fill=blue,width=2)
    for j in range(6):
        x0,y0=143+j*48,740
        points=[(x0+sin(t*.9+j)*38+t*(j-2)*12,y0-t*(56+j%3*10)) for t in range(7)]
        d.line(points,fill="#4e6150",width=5)
        for t,(x,y) in enumerate(points[1:]):
            for side in (-1,1):
                leaf(d,x,y,rng.uniform(45,75),-1.5+side*(.76+.13*t),rng.choice(["#4b675d","#697c63","#778672","#315952"]))
        if j%2==0:
            x,y=points[-1]
            for _ in range(5):
                ax,ay=x+rng.randrange(-21,22),y+rng.randrange(-3,39)
                d.ellipse((ax,ay,ax+18,ay+19),fill="#9e5e42",outline="#795541",width=2)
    d.line((52,774,588,774),fill=blue,width=2)
    label(d,(47,790),"植物观察手记",34,blue,True); label(d,(49,846),"粤海校园     ·     自然观察系列",17)
    write("field-notes",im)
    im,d=new((640,900),"#d8ddd4")
    d.rectangle((0,0,640,68),fill=blue);label(d,(35,11),"校园步行指南    /    WALKING GUIDE",23,"#ede6cd")
    label(d,(36,91),"从这里出发",64,blue,True);label(d,(37,192),"雨天也能走一小段",27)
    d.rectangle((36,281,604,690),fill="#c5c6ad")
    for j in range(45):
        x,y=rng.randint(40,575),rng.randint(285,651);w,h=rng.randint(15,66),rng.randint(8,31)
        d.rectangle((x,y,x+w,y+h),fill=rng.choice(["#abb5a1","#9baaa0","#a0aaa0"]))
    path=[(72,619),(181,619),(181,510),(340,510),(393,443),(550,390)]
    d.line(path,fill="#f5e9c8",width=17);d.line(path,fill="#946243",width=6)
    for j,(x,y) in enumerate(path[::2]):
        d.ellipse((x-10,y-10,x+10,y+10),fill=blue);label(d,(x+15,y-28),str(j+1),18)
    label(d,(36,725),"致理楼   —   庭院   —   连廊",28,blue,True)
    label(d,(36,797),"粤海 · 雨季步行计划",22); d.line((38,857,598,857),fill=blue,width=2)
    write("walking",im)
    im,d=new((1024,382),"#244655")
    d.rectangle((11,10,1011,372),outline="#8c9c9b",width=2)
    label(d,(44,36),"致理楼",114,"#f1eddd",True);label(d,(690,20),"C",200,"#e9ebd9")
    d.line((49,232,971,232),fill="#b5c4bc",width=3)
    label(d,(50,253),"Z H I L I    B U I L D I N G",32,"#e0e5d6")
    label(d,(52,315),"粤海校区   /   YUEHAI CAMPUS",20,"#c1d1c7")
    write("zhili-plate",im)
    im,d=new((640,196),"#e2dfcc");d.rectangle((0,0,17,196),fill=blue)
    label(d,(43,14),"公共饮水处",55,blue,True);label(d,(46,105),"DRINKING WATER     /     小心地滑",25)
    write("water",im)

if __name__ == "__main__":
    prepare(sys.argv[1])
