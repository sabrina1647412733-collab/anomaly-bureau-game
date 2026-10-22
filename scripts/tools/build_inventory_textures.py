"""Original UI materials for offline Godot item stills. No external assets required.
python scripts/tools/build_inventory_textures.py
"""
from pathlib import Path
import math, random
from PIL import Image, ImageDraw, ImageFont
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/ui/inventory/materials'
OUT.mkdir(parents=True, exist_ok=True)
FONT = str(ROOT/'assets/fonts/NotoSansSC-Regular.otf')
rng = random.Random(184)
def font(n): return ImageFont.truetype(FONT,n)
def paper(name, size=(700,950), base=(208,195,163)):
    im=Image.new('RGB',size,base); px=im.load()
    for y in range(size[1]):
        for x in range(size[0]):
            n=rng.randrange(-5,6)-int(9*abs(x/size[0]-.5))
            px[x,y]=tuple(max(0,min(255,c+n)) for c in base)
    return im,ImageDraw.Draw(im)
def save(im,name): im.save(OUT/(name+'.png'))
# Small tile shared by all inventory panels. Texture variation stays below text contrast.
grain=Image.new('RGB',(128,128));grain.putdata([(g,g-1,g-3) for g in [rng.randrange(48,82) for _ in range(128*128)]])
grain.save(OUT.parent/'grain.png')
im,d=paper('envelope',(960,620),(203,181,143))
d.line([(0,0),(480,337),(960,0)],fill=(113,95,69),width=4)
d.line([(0,620),(348,267)],fill=(155,131,97),width=3)
d.line([(960,620),(612,267)],fill=(155,131,97),width=3)
d.rectangle((610,376,898,544),outline=(137,63,47),width=5)
d.text((632,395),'入职通知',font=font(48),fill=(143,62,45))
d.text((635,465),'派遣科 · 急件',font=font(28),fill=(143,62,45))
d.rectangle((800,54,892,166),outline=(113,94,65),width=4)
d.line((811,65,883,157),fill=(148,119,80),width=2)
save(im,'envelope')
for name,heading,sub in [('document','现场调查记录','老街 27 号'),('registered','挂号邮政存档','27—503—1107'),('pipe_map','全楼管线图','屋顶 → 后房 → B1'),('badge','临时派遣证','许砚 / 临—0131'),('permcard','录名权限卡','派遣科 / 已录名')]:
    im,d=paper(name)
    d.rectangle((28,28,672,922),outline=(151,135,104),width=2)
    d.text((68,84),heading,font=font(42),fill=(64,64,53))
    d.text((70,165),sub,font=font(24),fill=(104,95,74))
    d.line((66,222,636,222),fill=(128,114,85),width=3)
    if name=='pipe_map':
        for x,y,w,label in [(110,310,450,'屋顶旁通'),(110,480,310,'二层后房'),(310,700,310,'B1蓄水池')]:
            d.rectangle((x,y,x+w,y+90),outline=(64,81,74),width=5)
            d.text((x+18,y+20),label,font=font(28),fill=(64,81,74))
        d.line([(340,400),(340,450),(250,450),(250,480)],fill=(64,81,74),width=7)
        d.line([(270,570),(270,650),(470,650),(470,700)],fill=(64,81,74),width=7)
    else:
        for row in range(10):
            y=280+row*41
            d.line((70,y,70+rng.randrange(280,555),y),fill=(126,117,96),width=5 if row%3 else 8)
        d.rectangle((390,749,616,857),outline=(136,64,48),width=4)
        d.text((414,776),'留存备查',font=font(34),fill=(136,64,48))
    save(im,name)
# family_photo_v1.png is original generated art, retained unchanged; see ART_SOURCES.md.
im=Image.new('RGB',(480,960),(18,24,25));d=ImageDraw.Draw(im)
d.rounded_rectangle((12,12,468,948),radius=24,fill=(27,42,42))
d.text((54,82),'23:40',font=font(83),fill=(227,221,201))
d.text((57,185),'微语',font=font(25),fill=(154,180,160))
for i in range(3):
    d.rounded_rectangle((39,270+i*116,441,364+i*116),radius=12,fill=(44,63,58))
    d.ellipse((58,291+i*116,107,340+i*116),fill=(125,137,115))
    for y,w in [(291,240),(322,176)]:d.line((130,y+i*116,w+100,y+i*116),fill=(169,177,159),width=8 if y==291 else 4)
for i,color in enumerate([(124,153,123),(116,133,149),(168,145,94),(143,121,116)]):
    x=62+i*104;d.rounded_rectangle((x,773,x+65,838),radius=16,fill=color)
d.line((175,914,305,914),fill=(192,198,185),width=7)
save(im,'phone_screen')
im=Image.new('RGBA',(700,700),(0,0,0,0));d=ImageDraw.Draw(im)
d.ellipse((10,10,690,690),fill=(221,208,170),outline=(100,84,56),width=11)
d.ellipse((32,32,668,668),outline=(152,129,89),width=3)
for i in range(60):
    a=i*math.tau/60-math.pi/2;r0=282 if i%5 else 267
    d.line((350+math.cos(a)*r0,350+math.sin(a)*r0,350+math.cos(a)*302,350+math.sin(a)*302),fill=(75,72,58),width=3 if i%5 else 5)
for i in range(1,13):
    a=i*math.tau/12-math.pi/2;x=350+math.cos(a)*232;y=350+math.sin(a)*232
    t=str(i);bbox=d.textbbox((0,0),t,font=font(49));d.text((x-(bbox[2]-bbox[0])/2,y-32),t,font=font(49),fill=(49,51,44))
d.line((350,350,350,187),fill=(45,48,42),width=13)
d.line((350,350,476,403),fill=(45,48,42),width=16)
d.ellipse((333,333,367,367),fill=(126,100,52))
save(im,'clock_face')
for name,tag in [('key','检修'),('back_key','后房'),('drawer_key','303'),('mail_key','503'),('tool_key','检修'),('machine_key','07')]:
    im,d=paper(name,(300,420),(197,181,143))
    d.rectangle((14,14,286,406),outline=(125,106,71),width=4)
    d.ellipse((124,28,176,80),fill=(71,65,48))
    d.text((35,172),tag,font=font(74 if tag.isdigit() else 64),fill=(66,64,49))
    d.line((40,313,260,313),fill=(122,108,80),width=3)
    save(im,name)
print('INVENTORY_MATERIALS',OUT)
