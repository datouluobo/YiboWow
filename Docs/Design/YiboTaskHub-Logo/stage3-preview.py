"""Arrange native SVG renders and inspect alpha; no image-generation edits."""
from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
import json
root=Path(__file__).resolve().parent
sheet=Image.new('RGB',(1024,610),'#11171b')
d=ImageDraw.Draw(sheet)
font=lambda size: ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',size)
d.text((32,22),'YiboTaskHub · F 的 32px 矢量骨架',font=font(25),fill='#eef1f3')
d.text((32,64),'阶段 3 · 待确认   /   仅确认形状与比例',font=font(15),fill='#aebbc1')
d.rounded_rectangle((32,110,392,475),radius=10,fill='#1b242a',outline='#354148')
im=Image.open(root/'stage3-F-draft-320.png')
sheet.paste(im,(52,130),im)
for n in range(33):
    pos=52+n*10
    d.line((pos,130,pos,450),fill='#354148',width=1)
    pos=130+n*10
    d.line((52,pos,372,pos),fill='#354148',width=1)
d.text((46,490),'32×32 网格放大图（每格 1px）',font=font(14),fill='#aebbc1')
d.text((442,115),'实尺寸预览',font=font(19),fill='#eef1f3')
checks=[]
for size,x in [(32,460),(24,645)]:
    thumb=Image.open(root/f'stage3-F-draft-{size}.png')
    d.text((x,154),f'{size}×{size}',font=font(14),fill='#aebbc1')
    for y,bg in [(195,'#1b242a'),(257,'#e8ecee')]:
        d.rounded_rectangle((x-8,y-8,x+size+8,y+size+8),radius=5,fill=bg)
        sheet.paste(thumb,(x,y),thumb)
    a=thumb.getchannel('A')
    edge=list(a.crop((0,0,size,1)).getdata())+list(a.crop((0,size-1,size,size)).getdata())+list(a.crop((0,0,1,size)).getdata())+list(a.crop((size-1,0,size,size)).getdata())
    checks.append({'size':size,'alpha_range':a.getextrema(),'edge_alpha_max':max(edge),'bbox':a.getbbox()})
d.text((442,333),'保留：微斜卷轴、纸面内粗直箭头',font=font(16),fill='#e6ecee')
d.text((442,368),'收紧：卷轴与环框间距，卷边细节',font=font(16),fill='#aebbc1')
d.text((442,403),'3 个主块：六边形框 / 卷轴 / 箭头',font=font(16),fill='#aebbc1')
d.text((32,549),'仅骨架草案；尚未添加青绿配色、WoW 材质、光效或游戏 UI 模拟。',font=font(14),fill='#aebbc1')
sheet.save(root/'stage3-preview.png')
(root/'stage3-checks.json').write_text(json.dumps(checks,indent=2),encoding='utf-8')
print(json.dumps(checks))
