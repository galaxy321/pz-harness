import sys, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageEnhance
F='/tmp/claude-0/s/f/'; OUT='/mnt/project-files/test-ground/release/art-v2/'
B='/usr/share/fonts/opentype/inter/Inter-Bold.otf'; X='/usr/share/fonts/opentype/inter/Inter-ExtraBold.otf'
M='/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf'
def font(p,s):
    try: return ImageFont.truetype(p,s)
    except: return ImageFont.truetype(B,s)
GREEN=(120,230,120); AMBER=(255,190,60); WHITE=(245,245,238)
def bg(src,box,dark=.55,blur=0):
    im=Image.open(F+src).convert('RGB').crop(box).resize((512,512),Image.LANCZOS)
    if blur: im=im.filter(ImageFilter.GaussianBlur(blur))
    return ImageEnhance.Brightness(im).enhance(dark)
def fit(d,text,path,maxw,start):
    s=start
    while d.textlength(text,font=font(path,s))>maxw: s-=2
    return font(path,s)
def shade(im,y0,y1,a0,a1):
    ov=Image.new('RGBA',im.size,(0,0,0,0)); d=ImageDraw.Draw(ov)
    for y in range(y0,y1):
        a=int(a0+(a1-a0)*(y-y0)/max(1,y1-y0)); d.line([(0,y),(512,y)],fill=(10,12,10,a))
    return Image.alpha_composite(im.convert('RGBA'),ov).convert('RGB')
def graph(d,x0,x1,ybase,amp,color,seed,w=5):
    random.seed(seed); pts=[]; n=26
    for i in range(n):
        v=random.uniform(.15,.4)
        if i in (8,17): v=random.uniform(.85,1)
        pts.append((x0+(x1-x0)*i/(n-1), ybase-amp*v))
    d.line(pts,fill=(0,0,0),width=w+4,joint='curve'); d.line(pts,fill=color,width=w,joint='curve')
    for p in pts[8:9]+pts[17:18]: d.ellipse([p[0]-7,p[1]-7,p[0]+7,p[1]+7],fill=color,outline=(0,0,0),width=2)
def centered(d,y,text,f,fill,shadow=True):
    w=d.textlength(text,font=f); x=(512-w)/2
    if shadow: d.text((x+3,y+3),text,font=f,fill=(0,0,0),)
    d.text((x,y),text,font=f,fill=fill)
def render(item,var):
    addon=item=='addon'; acc=AMBER if addon else GREEN
    if var=='A':   # frame-time graph over the road
        im=bg('drive14.png',(780,100,1240,560),.6); im=shade(im,0,512,60,150)
        d=ImageDraw.Draw(im); graph(d,28,484,398,95,acc,1+addon)
        d.line([(28,402),(484,402)],fill=(255,255,255,90),width=1)
        centered(d,10,'PZ',fit(d,'PZ',X,440,132),WHITE); centered(d,170,'HARNESS',fit(d,'HARNESS',X,440,80),WHITE)
        sub='DEV ADD-ON' if addon else 'PERFORMANCE TEST BENCH'
        f=fit(d,sub,B,440,40 if addon else 30)
        if addon:
            w=d.textlength(sub,font=f); d.rounded_rectangle([(512-w)/2-18,428,(512+w)/2+18,428+58],12,fill=acc)
            d.text(((512-w)/2,428+(58-f.size)/2-3),sub,font=f,fill=(20,20,10))
        else: centered(d,440,sub,f,WHITE)
    elif var=='B': # framed crop, title band on top
        im=bg('fight8.png',(760,140,1240,620),.9) if not addon else bg('drive3.png',(760,60,1240,540),.9)
        d=ImageDraw.Draw(im); d.rectangle([0,0,512,200],fill=(18,22,18)); d.rectangle([0,200,512,206],fill=acc)
        centered(d,16,'PZ HARNESS',fit(d,'PZ HARNESS',X,460,100),WHITE,False)
        sub='DEV ADD-ON' if addon else 'Frame-time test bench'
        centered(d,130,sub,fit(d,sub,B,440,50),acc,False)
        d.rectangle([0,430,512,512],fill=(18,22,18)); d.rectangle([0,424,512,430],fill=acc)
        t='drive · fight · crowd' if not addon else 'scripts + AI agents'
        centered(d,448,t,fit(d,t,B,440,34),WHITE,False)
    elif var=='C': # dark panel, stacked, graph + mono readout
        im=Image.new('RGB',(512,512),(22,26,34) if addon else (22,30,24)); d=ImageDraw.Draw(im)
        for y in range(0,512,32): d.line([(0,y),(512,y)],fill=(255,255,255,18) if False else (40,46,52))
        centered(d,30,'PZ',fit(d,'PZ',X,300,120),acc,False); centered(d,150,'HARNESS',fit(d,'HARNESS',X,440,84),WHITE,False)
        if addon:
            f=font(M,38)
            for i,l in enumerate(['> status','> baseline','=== done']): d.text((70,262+i*52),l,font=f,fill=acc)
            tag='DEV ADD-ON'; w=d.textlength(tag,font=font(B,36)); d.rounded_rectangle([(512-w)/2-16,436,(512+w)/2+16,492],12,fill=acc); d.text(((512-w)/2,442),tag,font=font(B,36),fill=(20,20,10))
        else:
            graph(d,30,482,400,150,acc,5,6)
            centered(d,430,'FRAME-TIME TEST BENCH',fit(d,'FRAME-TIME TEST BENCH',B,440,32),WHITE,False)
    return im
def icon(item):
    addon=item=='addon'; acc=AMBER if addon else GREEN
    im=Image.new('RGB',(256,256),(22,28,24)); d=ImageDraw.Draw(im)
    f=fit(d,'PZ',X,220,170); w=d.textlength('PZ',font=f); d.text(((256-w)/2,10),'PZ',font=f,fill=WHITE)
    random.seed(3); pts=[(14+i*(228/9),205-[10,25,12,60,18,10,70,15,20,12][i]) for i in range(10)]
    d.line(pts,fill=acc,width=14,joint='curve')
    if addon: d.rounded_rectangle([140,150,250,250],20,fill=acc); d.text((195,200),'+',font=font(X,100),fill=(20,20,10),anchor='mm')
    return im.resize((64,64),Image.LANCZOS)
for item,name in (('core','PZHarness'),('addon','PZHarnessDevAddon')):
    for v in 'ABC': render(item,v).save(f'{OUT}{name}-preview-{v}.png')
    render(item,'A').resize((256,256),Image.LANCZOS).save(f'{OUT}{name}-preview-256.png')
    render(item,'C').save(f'{OUT}{name}-poster.png')
    icon(item).save(f'{OUT}{name}-icon.png')
