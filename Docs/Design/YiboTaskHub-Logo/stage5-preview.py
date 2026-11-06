"""Diagnostic preview of stage 5 generated material; source pixels unmodified."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json
root=Path(__file__).resolve().parent
sheet=Image.new('RGB',(1040,730),'#101619')
d=ImageDraw.Draw(sheet)
font=lambda n:ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',n)
def text(x,y,t,n=14,c='#b4c2c8'):d.text((x,y),t,font=font(n),fill=c)
imgs={s:Image.open(root/f'stage5-F-style-{s}-preview.png').convert('RGBA') for s in (24,32,64,128)}
def icon(s,x,y):sheet.paste(imgs[s],(x,y),imgs[s])
text(32,22,'YiboTaskHub · F 风格化材质预览',26,'#edf1f3')
text(32,68,'阶段 5 · 待确认  |  暖色纸张 / 深色金属 / 青绿识别线',15)
d.rounded_rectangle((32,108,430,496),radius=10,fill='#1a2329',outline='#39444a')
# Magnify 128px diagnostic preview, never present it as final artwork.
large=imgs[128].resize((320,320),Image.Resampling.NEAREST)
sheet.paste(large,(71,132),large)
text(50,470,'128px 预览放大 · 用于查看材质',13)
d.rounded_rectangle((450,108,1008,496),radius=10,fill='#1a2329',outline='#39444a')
text(470,128,'实尺寸 · 深色 / 浅色对照',18,'#edf1f3')
for s,x in [(24,505),(32,669),(64,848)]:
    text(x-3,172,f'{s}×{s}',14)
    for y,bg in [(215,'#080e12'),(300,'#e5e9eb')]:
        d.rectangle((x-8,y-8,x+s+8,y+s+8),fill=bg)
        icon(s,x,y)
text(470,409,'已确认骨架',13)
previous=Image.open(root/'stage4-F-preview-64.png')
sheet.paste(previous,(585,398),previous)
text(675,424,'同一主意象与构图',13)
d.rounded_rectangle((32,518,1008,657),radius=10,fill='#1a2329',outline='#39444a')
text(52,533,'入口实尺寸模拟',17,'#edf1f3')
d.rectangle((52,574,620,630),fill='#0b1014',outline='#465057')
icon(24,70,590)
text(105,591,'行动中心',14,'#e8d7a9')
text(242,591,'Broker / 紧凑列表 · 24px',13)
d.ellipse((691,575,745,629),fill='#090e12',outline='#82744f',width=2)
icon(32,702,586)
text(765,591,'小地图按钮 · 32px',13)
text(32,681,'材质草案缩览；最终 24/32px 仍需下一阶段逐像素修整。尚未接入游戏。',13)
sheet.save(root/'stage5-preview.png')
checks=[]
for s,im in imgs.items():
    a=im.getchannel('A')
    edge=[a.crop(b).get_flattened_data() for b in [(0,0,s,1),(0,s-1,s,s),(0,0,1,s),(s-1,0,s,s)]]
    checks.append({'size':s,'mode':im.mode,'alpha_range':a.getextrema(),'edge_alpha_max':max(v for e in edge for v in e),'bbox':a.getbbox()})
src=Image.open(root/'stage5-F-style-source-draft.png')
result={'status':'awaiting approval','source_size':src.size,'source_mode':src.mode,'previews':checks,'note':'Material concept previews; no pixel cleanup performed.'}
(root/'stage5-checks.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result))
