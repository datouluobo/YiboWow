"""Export the approved sheet as temporary Broker test textures; no redraw."""
from pathlib import Path
import hashlib
import json
import shutil
import numpy as np
from scipy import ndimage
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
SOURCE = Path('C:/Users/Administrator/.codex/generated_images/01a13542-984b-75d1-a79b-41af5db0dd60/exec-779dd28d-983f-40a4-b92e-1fa020d2c4c5.png')
NAMES = ['Core','Mail','Vault','Builds','AutoOpen','Currency','Crafting','Todo','Reputation','AltoBoss','Legendary','Mounts','BeastPaths','QuestBlocker','TaskHub']
def main():
    media = ROOT / 'Media'
    media.mkdir(parents=True, exist_ok=True)
    shutil.copy2(SOURCE, ROOT / 'ApprovedOverview.png')
    source = Image.open(SOURCE).convert('RGB')
    assert source.size == (1420, 1108)
    records = []
    preview = Image.new('RGB', (780, 15 * 82 + 44), '#202126')
    draw = ImageDraw.Draw(preview)
    font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 15)
    draw.text((12, 12), 'Temporary Broker textures: 16 / 24 / 32 / 64 px (native size)', font=font, fill='white')
    for i, short in enumerate(NAMES):
        name = 'Yibo' + short
        cx = [162,435,708,980,1254][i % 5]
        cy = [254,558,860][i // 5]
        # Separate cells from labels; shared frame center and shared canvas scale.
        crop = source.crop((cx-122, cy-140, cx+122, cy+122))
        rgb = np.array(crop).astype(np.int16)
        barrier = (rgb.max(2) > 66) & ((rgb.max(2)-rgb.min(2)) > 25)
        # Closed colored frame protects the dark interior during exterior removal.
        # Include disconnected foreground/frame islands and seal tiny raster gaps.
        mask = ndimage.binary_fill_holes(ndimage.binary_closing(barrier, iterations=2))
        mask = ndimage.binary_dilation(mask, iterations=1)
        rgba = crop.convert('RGBA')
        rgba.putalpha(Image.fromarray((mask * 255).astype('uint8')))
        master = Image.new('RGBA', (296,296))
        master.alpha_composite(rgba, (26,8))
        # Source frame center stays at (148,148); common scaling for all logos.
        master.save(media / (name + '-source.png'))
        draw.text((12, 52+i*82), name, font=font, fill='white')
        for size, x in [(16,190),(24,250),(32,320),(64,410)]:
            icon = master.resize((size,size), Image.Resampling.LANCZOS)
            # Remove subpixel resampling ringing at the transparent canvas edge.
            pixels = np.array(icon)
            for edge in (pixels[0,:,3], pixels[-1,:,3], pixels[:,0,3], pixels[:,-1,3]):
                assert edge.max() <= 16, (name,size,'subject crosses edge',int(edge.max()))
                edge[:] = 0
            icon = Image.fromarray(pixels)
            icon.save(media / f'{name}-{size}.png')
            if size in (32,64):
                icon.save(media / f'{name}-{size}.tga', compression=None)
            preview.paste(icon, (x,48+i*82), icon)
            a = np.array(icon.getchannel('A'))
            assert not (a[0].any() or a[-1].any() or a[:,0].any() or a[:,-1].any()), (name,size,'edge alpha')
        records.append({'addon':name,'center':[cx,cy],'texture':f'Media/{name}-64.tga'})
    preview.save(ROOT / 'NativeSizePreview.png')
    (ROOT / 'Manifest.json').write_text(json.dumps({'status':'temporary-client-validation','source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'sizes':[16,24,32,64],'game_textures':[32,64],'icons':records},ensure_ascii=False,indent=2),encoding='utf-8')
    print('Exported 15 icons; 60 PNG sizes, 30 RGBA TGA textures; alpha edges verified.')

if __name__ == '__main__':
    main()
