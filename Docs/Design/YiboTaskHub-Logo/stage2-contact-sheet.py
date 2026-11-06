"""Build a diagnostic contact sheet; never modify generated source images."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parent
sheet = Image.new('RGB', (1184, 850), '#11171b')
draw = ImageDraw.Draw(sheet)
font_path = 'C:/Windows/Fonts/msyh.ttc'
font = ImageFont.truetype(font_path, 16)
title = ImageFont.truetype(font_path, 27)
small = ImageFont.truetype(font_path, 12)
labels = ['宽卷轴 · 直箭头', '窄卷轴 · 直箭头', '横宽卷轴 · 大箭头', '卷轴 · 折向箭头', '纸角融合箭头', '镂空直箭头', '不对称卷边', '弧形推进箭头']
draw.text((32, 24), 'YiboTaskHub · 轮廓方向 A–H', font=title, fill='#e6ecee')
draw.text((32, 70), '阶段 2 · 待确认  |  大形状与明暗探索  |  原始 PNG 保持透明', font=font, fill='#a8b4ba')
for i, label in enumerate(labels):
    key = chr(65+i)
    x, y = 32+(i%4)*284, 115+(i//4)*330
    draw.rounded_rectangle((x, y, x+268, y+310), radius=10, fill='#1b242a', outline='#354148')
    draw.text((x+16, y+14), key, font=title, fill='white')
    draw.text((x+52, y+23), label, font=font, fill='#e6ecee')
    source = Image.open(root/f'stage2-{key}-draft.png').convert('RGBA')
    # Thumbnails are concept comparisons, not exported game assets or pixel skeletons.
    large = source.resize((156, 156), Image.Resampling.LANCZOS)
    sheet.paste(large, (x+56, y+67), large)
    draw.line((x+16, y+237, x+252, y+237), fill='#354148')
    for size, dx in [(32, 22), (24, 151)]:
        draw.text((x+dx, y+255), f'{size}px', font=small, fill='#c1ccd1')
        thumb = source.resize((size, size), Image.Resampling.LANCZOS)
        sheet.paste(thumb, (x+dx+45, y+247), thumb)
    draw.text((x+16, y+287), '3 个主块：外框 / 卷轴 / 箭头', font=small, fill='#95a3aa')
draw.text((32, 798), '24/32px 为概念缩览；选定后手工建立 32px 矢量骨架。尚未进行像素修整或游戏内验收。', font=small, fill='#a8b4ba')
sheet.save(root/'stage2-preview.png')
