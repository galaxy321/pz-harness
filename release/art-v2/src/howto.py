from PIL import Image, ImageDraw, ImageFont, ImageFilter
SRC='/mnt/project-files/menu-benchmark-dialog-11342.png'; OUT='/mnt/project-files/test-ground/release/art-v2/'
im=Image.open(SRC).convert('RGB')
I='/usr/share/fonts/opentype/inter/'
def F(n,s): return ImageFont.truetype(I+n,s)
def mask(box,size=31):
    pad=40; x0,y0,x1,y1=box
    reg=im.crop((x0-pad if x0>=pad else 0,max(0,y0-pad),x1+pad,y1+pad))
    bg=reg.filter(ImageFilter.MinFilter(size)).filter(ImageFilter.GaussianBlur(10))
    ox,oy=(x0-pad if x0>=pad else 0),max(0,y0-pad)
    im.paste(bg.crop((x0-ox,y0-oy,x1-ox,y1-oy)),(x0,y0))
# user's own mods: ZombieBuddy banner, PZ Optimization entries, pzBullet in version line
quit_=im.crop((50,1318,200,1372))
mask((0,0,124,124),81); mask((118,0,790,60))
mask((50,1166,680,1300)); mask((50,1316,210,1374))
im.paste(quit_,(50,1318-138))
mask((1040,1408,1520,1440))
# tour test rows -> plain save names
d=ImageDraw.Draw(im); f=F('Inter-SemiBold.otf',17)
names=[('Lumberjack','Sandbox'),('Riverside run','Apocalypse'),('Muldraugh base','Sandbox'),('West Point start','Survivor'),
       ('Rosewood farm','Sandbox'),('Louisville trip','Apocalypse'),('Day one','Survivor')]
tops=[574,614,654,694,734,774,814]
for (n,m),t in zip(names,tops):
    bot=min(t+38,834)
    row=Image.new('RGB',(1626-921,38),(2,2,3)); rd=ImageDraw.Draw(row)
    rd.text((15,24),n,font=f,fill=(206,206,206),anchor='ls')
    w=rd.textlength(n,font=f); rd.text((15+w+14,24),f'({m})',font=f,fill=(206,206,206),anchor='ls')
    im.paste(row.crop((0,0,row.width,bot-t)),(921,t))
# annotations
GREEN=(120,230,120); INK=(16,20,16); WHITE=(245,245,238)
ov=Image.new('RGBA',im.size,(0,0,0,0)); o=ImageDraw.Draw(ov)
tb=F('Inter-Bold.otf',46); ts=F('Inter-SemiBold.otf',34); nb=F('Inter-ExtraBold.otf',52)
def callout(x,y,num,title,sub):
    w=max(o.textlength(title,font=tb),o.textlength(sub,font=ts))+150
    o.rounded_rectangle([x,y,x+w,y+128],22,fill=(12,14,12,235),outline=GREEN,width=4)
    o.ellipse([x+22,y+24,x+102,y+104],fill=GREEN); o.text((x+62,y+64),str(num),font=nb,fill=INK,anchor='mm')
    o.text((x+124,y+18),title,font=tb,fill=WHITE); o.text((x+124,y+74),sub,font=ts,fill=(200,210,200))
    return (x,y,x+w,y+128)
def arrow(p0,p1,w=10):
    import math
    o.line([p0,p1],fill=(0,0,0,200),width=w+6); o.line([p0,p1],fill=GREEN,width=w)
    a=math.atan2(p1[1]-p0[1],p1[0]-p0[0]); L=40
    pts=[p1,(p1[0]-L*math.cos(a-0.45),p1[1]-L*math.sin(a-0.45)),(p1[0]-L*math.cos(a+0.45),p1[1]-L*math.sin(a+0.45))]
    o.polygon(pts,fill=GREEN,outline=(0,0,0))
def ring(box): o.rounded_rectangle(box,10,outline=GREEN,width=6)
ring((12,1378,198,1420)); ring((912,524,1636,840)); ring((912,948,1488,988))
c1=callout(300,1250,1,'Click Benchmark Save','bottom left of the main menu'); arrow((c1[0],c1[1]+64),(208,1395))
c2=callout(1720,560,2,'Pick a save','it runs on a copy of it'); arrow((c2[0],c2[1]+64),(1648,640))
c3=callout(912,1060,3,'Full or Quick test','about 15 min, or about 5 min'); arrow((1200,c3[1]),(1200,1000))
im=Image.alpha_composite(im.convert('RGBA'),ov).convert('RGB')
im.save(OUT+'howto-benchmark-save-2560.png')
im.resize((1920,1080),Image.LANCZOS).save(OUT+'howto-benchmark-save-1920.png')
im.resize((1280,720),Image.LANCZOS).save('/tmp/claude-0/s/howto-1280.png')
