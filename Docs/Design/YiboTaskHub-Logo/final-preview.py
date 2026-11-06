from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json
root=Path(__file__).resolve().parent
media=root.parents[2]/'YiboTaskHub'/'Media'
sheet=Image.new('RGB',(920,430),'#11171b');d=ImageDraw.Draw(sheet)
font=lambda n:ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',n)
d.text((28,20),'YiboTaskHub · v1 已接入插件',font=font(25),fill='#ecf1f3')
large=Image.open(media/'YiboTaskHubIcon-v1-128.png').resize((256,256),Image.Resampling.NEAREST)
sheet.paste(large,(36,95),large)
for s,x in [(24,370),(32,530),(64,710)]:
    d.text((x,100),f'{s}×{s}',font=font(15),fill='#aebbc1')
    im=Image.open(media/f'YiboTaskHubIcon-v1-{s}.png')
    for y,c in [(150,'#090e12'),(245,'#e8ecee')]:
        d.rectangle((x-8,y-8,x+s+8,y+s+8),fill=c);sheet.paste(im,(x,y),im)
d.text((28,385),'PNG / TGA：24、32、64、128、512、1024px · 四边透明 · TOC 插件列表图标已配置',font=font(13),fill='#aebbc1')
sheet.save(root/'final-preview.png')
for s in (24,32,64,128,512,1024):
    png=Image.open(media/f'YiboTaskHubIcon-v1-{s}.png').convert('RGBA')
    tga=Image.open(media/f'YiboTaskHubIcon-v1-{s}.tga').convert('RGBA')
    assert png.size==(s,s) and png.tobytes()==tga.tobytes(),s
assert Image.open(media/'YiboTaskHubIcon-v1.tga').size==(128,128)
print('PNG/TGA six sizes: dimensions and RGBA pixels match; default TGA 128px.')
