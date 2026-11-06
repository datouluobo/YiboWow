"""Render a review-only 32px comparison for five ImageGen refinements."""
from pathlib import Path
import shutil
import numpy as np
from scipy import ndimage
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
SOURCE = Path('C:/Users/Administrator/.codex/generated_images/01a13542-984b-75d1-a79b-41af5db0dd60/exec-e1448043-c095-468f-81ac-e795cf80b6e4.png')
ITEMS = [('YiboCore',162,254),('YiboAutoOpen',1254,254),('YiboCrafting',435,558),('YiboAltoBoss',1254,558),('YiboQuestBlocker',980,860)]

def main():
    shutil.copy2(SOURCE, ROOT/'Overview.png')
    source=Image.open(SOURCE)
    assert source.mode=='RGBA' and source.size==(1420,1108)
    sheet=Image.new('RGB',(800,len(ITEMS)*178+66),'#777777')
    draw=ImageDraw.Draw(sheet)
    font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',16)
    draw.text((16,12),'32px review: current / simplified (pending approval)',font=font,fill='white')
    for x,label in [(200,'Current 32'),(330,'Draft 32'),(455,'Current x4'),(620,'Draft x4')]:
        draw.text((x,39),label,font=font,fill='white')
    for i,(name,cx,cy) in enumerate(ITEMS):
        crop=source.crop((cx-148,cy-148,cx+148,cy+148))
        pixels=np.array(crop)
        labels,_=ndimage.label(pixels[:,:,3]>=128)
        sizes=np.bincount(labels.ravel())
        keep=sizes>=64; keep[0]=False
        near=ndimage.binary_dilation(keep[labels],iterations=1)
        pixels[:,:,3][~near]=0
        pixels[:,:,3][pixels[:,:,3]<48]=0
        master=Image.new('RGBA',(312,312))
        master.alpha_composite(Image.fromarray(pixels),(8,8))
        master.save(ROOT/f'{name}-source.png')
        icon=master.resize((32,32),Image.Resampling.LANCZOS)
        pixels=np.array(icon)
        pixels[0,:,3]=pixels[-1,:,3]=pixels[:,0,3]=pixels[:,-1,3]=0
        icon=Image.fromarray(pixels)
        icon.save(ROOT/f'{name}-32.png')
        original=Image.open(ROOT.parent/'MediaTransparent'/f'{name}-32.png')
        y=76+i*178
        draw.text((16,y+30),name,font=font,fill='white')
        sheet.paste(original,(224,y+48),original)
        sheet.paste(icon,(354,y+48),icon)
        for x,item in [(455,original),(620,icon)]:
            zoom=item.resize((128,128),Image.Resampling.NEAREST)
            sheet.paste(zoom,(x,y),zoom)
    sheet.save(ROOT/'Compare32.png')
    print(f'{len(ITEMS)} review-only 32px PNGs and comparison generated. Runtime assets unchanged.')

if __name__=='__main__': main()
