"""Export stable current assets from addon-owned bitmap masters; never touch archives."""
from pathlib import Path
import hashlib
import json
import re
import shutil
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
DESIGN = ROOT / 'Docs/Design/Yibo系列Logo-20261014'
VERSIONS = {'YiboCore':21,'YiboMail':2,'YiboVault':3,'YiboBuilds':2,'YiboAutoOpen':3,
    'YiboCurrency':2,'YiboCrafting':3,'YiboTodo':7,'YiboReputation':2,'YiboAltoBoss':1,
    'YiboLegendary':2,'YiboMounts':2,'YiboBeastPaths':1,'YiboQuestBlocker':1,'YiboTaskHub':2}
SIZES = (16,24,32,64,128,512,1024)

def folder(addon):
    return 'Media'

def stem(addon): return f'{addon}Icon'

def export():
    DESIGN.mkdir(parents=True, exist_ok=True)
    approved = DESIGN / 'ApprovedOverview.png'
    manifest = {'date':'2026-10-14','source_sha256':hashlib.sha256(approved.read_bytes()).hexdigest(),
        'master_type':'RGBA bitmap','master_size':312,'default_game_texture_size':64,
        'sizes':list(SIZES),'assets':{},'changed_files':[]}
    preview = Image.new('RGB',(750,len(VERSIONS)*82+50),'#777777')
    draw=ImageDraw.Draw(preview)
    font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',15)
    draw.text((12,12),'Yibo icons: 24 / 32 / 64 px (native size)',font=font,fill='white')
    for i,addon in enumerate(VERSIONS):
        master=Image.open(ROOT/addon/'Media'/f'{stem(addon)}-master.png').convert('RGBA')
        assert master.size==(312,312)
        target=ROOT/addon/folder(addon); target.mkdir(parents=True,exist_ok=True)
        base=stem(addon)
        draw.text((12,58+i*82),addon,font=font,fill='white')
        for size in SIZES:
            icon=master.resize((size,size),Image.Resampling.LANCZOS)
            # Ensure the canvas border remains transparent after resampling.
            alpha=icon.getchannel('A')
            border=ImageDraw.Draw(alpha)
            border.rectangle((0,0,size-1,size-1),outline=0,width=1)
            icon.putalpha(alpha)
            icon.save(target/f'{base}-{size}.png')
            if size in (16,32,64,128,512,1024): icon.save(target/f'{base}-{size}.tga',compression=None)
            if size in (24,32,64):
                x={24:220,32:310,64:410}[size]
                preview.paste(icon,(x,50+i*82),icon)
        shutil.copy2(target/f'{base}-128.png', target/f'{base}.png')
        shutil.copy2(target/f'{base}-64.tga', target/f'{base}.tga')
        # A large bitmap logo and a 512px client-compatible presentation texture.
        shutil.copy2(target/f'{base}-1024.png',target/f'{addon}Logo.png')
        shutil.copy2(target/f'{base}-512.tga',target/f'{addon}Logo.tga')
        manifest['assets'][addon]={'directory':f'{addon}/Media','stem':base,'source_visual_revision':VERSIONS[addon],
            'archives':sorted(p.name for p in target.iterdir() if p.is_dir() and re.fullmatch(r'v\d+',p.name))}
    preview.save(DESIGN/'NativeSizePreview.png')
    return manifest

if __name__=='__main__':
    result=export()
    (DESIGN/'Manifest.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print(f'Exported {len(VERSIONS)} current addon asset sets; archives unchanged.')
