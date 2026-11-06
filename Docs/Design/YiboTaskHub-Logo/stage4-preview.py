"""Stage 4: arrange unchanged SVG renders in diagnostic UI simulations."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json
import hashlib

root = Path(__file__).resolve().parent
sheet = Image.new('RGB', (1056, 800), '#101619')
d = ImageDraw.Draw(sheet)
font = lambda size: ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', size)
images = {s: Image.open(root/f'stage4-F-preview-{s}.png').convert('RGBA') for s in (24,32,64)}
def text(x,y,value,size=14,color='#bcc7cc'):
    d.text((x,y),value,font=font(size),fill=color)
def icon(size,x,y):
    sheet.paste(images[size],(x,y),images[size])
def panel(box):
    d.rounded_rectangle(box,radius=10,fill='#1a2329',outline='#39444a')

text(32,24,'YiboTaskHub · F 实尺寸与 WoW UI 模拟',26,'#edf1f3')
text(32,70,'阶段 4 · 待确认   |   同一已确认骨架，未添加材质或光效',15)
panel((32,112,1024,330))
text(52,130,'实尺寸对照',18,'#edf1f3')
for size,x in [(24,242),(32,488),(64,748)]:
    text(x-8,132,f'{size}×{size}',14)
    for y,bg in [(174,'#090e12'),(249,'#e5e9eb')]:
        d.rectangle((x-9,y-9,x+size+9,y+size+9),fill=bg)
        icon(size,x,y)
text(52,192,'深色 UI',14)
text(52,267,'浅色对照',14)

# Broker strip: a native 24px icon within a compact dark status bar.
panel((32,354,648,483))
text(52,370,'Broker 行 · 24px',17,'#edf1f3')
d.rectangle((52,408,628,453),fill='#0b1014',outline='#465057')
text(64,421,'账号',13,'#88959c')
d.line((105,418,105,443),fill='#39444a')
icon(24,120,419)
text(152,421,'行动中心',14,'#e7d6a4')
text(252,421,'当前角色待办',13)
d.line((401,418,401,443),fill='#39444a')
text(416,421,'背包',13,'#88959c')

# A compact task-list row uses the exact 24px render without scaling.
panel((32,503,648,722))
text(52,520,'紧凑列表 · 24px',17,'#edf1f3')
d.rectangle((52,560,628,606),fill='#10171c',outline='#354148')
icon(24,66,571)
text(104,571,'行动中心',15,'#e7d6a4')
text(484,573,'账号任务',13)
d.line((52,620,628,620),fill='#354148')
text(68,634,'准备材料',14)
text(484,634,'可推进',13,'#a2b5aa')
text(68,670,'寄送成品',14)
text(484,670,'待处理',13,'#a9b4bc')

# Minimap surroundings are drawn schematic scenery, not a game screenshot.
panel((670,354,1024,722))
text(690,370,'小地图按钮 · 32px',17,'#edf1f3')
d.ellipse((709,420,987,698),fill='#303b35',outline='#82744f',width=5)
d.ellipse((719,430,977,688),outline='#171d20',width=3)
d.polygon([(740,480),(792,447),(842,470),(907,445),(957,491),(936,564),(883,545),(809,587),(753,552)],fill='#3c4b3b')
d.line([(741,613),(792,554),(849,535),(892,481),(943,462)],fill='#786b4b',width=6)
d.line([(732,489),(776,505),(820,549),(829,602),(852,672)],fill='#465d61',width=8)
text(842,434,'N',14,'#e7d6a4')
d.polygon([(842,559),(852,547),(856,564)],fill='#ddd8be')
d.ellipse((927,490,973,536),fill='#090e12',outline='#82744f',width=2)
icon(32,934,497)
text(706,697,'示意场景 · 未在客户端采样',12,'#9aa8ae')

text(32,747,'所有图标按标注像素原样放置；模拟环境用于判断轮廓与对比，界面文字仅为示例。',13)
text(32,773,'下一阶段获批后才添加青绿识别线、纸张与金属材质。',12,'#93a1a8')
sheet.save(root/'stage4-preview.png')

checks=[]
for size,im in images.items():
    a=im.getchannel('A')
    edges=[a.crop(box).get_flattened_data() for box in [(0,0,size,1),(0,size-1,size,size),(0,0,1,size),(size-1,0,size,size)]]
    check={'size':size,'mode':im.mode,'alpha_range':a.getextrema(),'edge_alpha_max':max(v for edge in edges for v in edge),'bbox':a.getbbox()}
    if size in (24,32):
        previous=Image.open(root/f'stage3-F-draft-{size}.png').convert('RGBA')
        check['matches_approved_stage3_pixels']=im.tobytes()==previous.tobytes()
    checks.append(check)
result={'status':'待确认','source_svg':'stage3-F-skeleton-draft.svg','source_sha256':hashlib.sha256((root/'stage3-F-skeleton-draft.svg').read_bytes()).hexdigest(),'renders':checks,'simulation':'schematic, no in-game verification'}
(root/'stage4-checks.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(result,ensure_ascii=False))
