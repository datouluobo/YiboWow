"""Export ImageGen RGBA cutouts into temporary Broker test textures."""
from pathlib import Path
import hashlib
import json
import shutil
import numpy as np
from scipy import ndimage
from PIL import Image, ImageDraw, ImageFont
from Export import NAMES

ROOT = Path(__file__).resolve().parent
SOURCE = Path('C:/Users/Administrator/.codex/generated_images/01a13542-984b-75d1-a79b-41af5db0dd60/exec-90dff6ec-0051-480d-9ca2-124839d40fb4.png')
MEDIA_NAME = 'MediaTransparent'
OVERVIEW_NAME = 'TransparentOverview.png'
PREVIEW_NAME = 'TransparentNativeSizePreview.png'
MANIFEST_NAME = 'TransparentManifest.json'
SQUARE_CROP = False

def main():
    media = ROOT / MEDIA_NAME
    media.mkdir(exist_ok=True)
    shutil.copy2(SOURCE, ROOT / OVERVIEW_NAME)
    source = Image.open(SOURCE)
    assert source.mode == 'RGBA' and source.size == (1420,1108)
    preview = Image.new('RGB', (780,15*82+44), '#777777')
    draw = ImageDraw.Draw(preview)
    font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf',15)
    draw.text((12,12),'Transparent Broker textures: 16 / 24 / 32 / 64 px',font=font,fill='white')
    records = []
    for i, short in enumerate(NAMES):
        name = 'Yibo'+short
        cx,cy = [162,435,708,980,1254][i%5],[254,558,860][i//5]
        crop = source.crop((cx-148,cy-148,cx+148,cy+148) if SQUARE_CROP else (cx-122,cy-140,cx+122,cy+122))
        pixels = np.array(crop)
        # Remove detached alpha export speckles; never fill interior holes.
        labels,count = ndimage.label(pixels[:,:,3] >= 128)
        sizes = np.bincount(labels.ravel())
        good = sizes >= 64
        good[0] = False
        solid = good[labels]
        near = ndimage.binary_dilation(solid,iterations=1)
        pixels[:,:,3][~near] = 0
        pixels[:,:,3][pixels[:,:,3] < 48] = 0
        rgba = Image.fromarray(pixels)
        master = Image.new('RGBA',(312,312))
        master.alpha_composite(rgba,(8,8) if SQUARE_CROP else (34,16))
        master.save(media / f'{name}-source.png')
        draw.text((12,52+i*82),name,font=font,fill='white')
        for size,x in [(16,190),(24,250),(32,320),(64,410)]:
            icon=master.resize((size,size),Image.Resampling.LANCZOS)
            pixels=np.array(icon)
            pixels[0,:,3]=pixels[-1,:,3]=pixels[:,0,3]=pixels[:,-1,3]=0
            icon=Image.fromarray(pixels)
            icon.save(media/f'{name}-{size}.png')
            if size in (32,64): icon.save(media/f'{name}-{size}.tga',compression=None)
            preview.paste(icon,(x,48+i*82),icon)
        records.append({'addon':name,'texture':f'{MEDIA_NAME}/{name}-64.tga'})
    preview.save(ROOT/PREVIEW_NAME)
    (ROOT/MANIFEST_NAME).write_text(json.dumps({'status':'temporary-client-validation','source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'sizes':[16,24,32,64],'game_textures':[32,64],'icons':records},indent=2),encoding='utf-8')
    print('Exported 15 RGBA cutouts; 60 PNG sizes and 30 TGA textures.')

if __name__=='__main__': main()
