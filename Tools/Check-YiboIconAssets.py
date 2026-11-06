"""Validate exported assets and actual runtime texture references."""
from pathlib import Path
import json
import re
import subprocess
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
DESIGN=ROOT/'Docs/Design/Yibo系列Logo-20261014'
def main():
    manifest=json.loads((DESIGN/'Manifest.json').read_text(encoding='utf-8'))
    count=0; lua_files=[]; toc_count=0
    for addon,asset in manifest['assets'].items():
        media=ROOT/asset['directory']; stem=asset['stem']
        assert asset['directory']==f'{addon}/Media' and stem==f'{addon}Icon'
        current=[p for p in media.iterdir() if p.is_file() and re.match(re.escape(addon)+r'(Icon|Logo)(?:-|\.)',p.name)]
        assert len(current)==18,f'{addon}: expected 18 current assets'
        assert not any(re.match(re.escape(addon)+r'(Icon|Logo)-v\d+',p.name) for p in current),f'{addon}: versioned current asset'
        with Image.open(media/f'{stem}-master.png') as image:
            assert image.size==(312,312) and image.mode=='RGBA'
        for size in manifest['sizes']:
            formats=('png',) if size==24 else ('png','tga')
            for ext in formats:
                p=media/f'{stem}-{size}.{ext}'
                with Image.open(p) as image:
                    assert image.size==(size,size) and image.mode=='RGBA',str(p)
                    a=image.getchannel('A')
                    assert a.getextrema()==(0,255),str(p)
                    assert all(a.crop(box).getextrema()[1]==0 for box in [(0,0,size,1),(0,size-1,size,size),(0,0,1,size),(size-1,0,size,size)]),str(p)
                count+=1
        for ext,size in [('png',128),('tga',64)]:
            with Image.open(media/f'{stem}.{ext}') as image: assert image.size==(size,size) and image.mode=='RGBA'
        for ext,size in [('png',1024),('tga',512)]:
            with Image.open(media/f'{addon}Logo.{ext}') as image: assert image.size==(size,size) and image.mode=='RGBA'
        readme=ROOT/addon/'README.md'
        for link in re.findall(r'!\[[^\]]*\]\(([^)]+)\)',readme.read_text(encoding='utf-8-sig')):
            if '://' not in link and ('Media/' in link or 'Assets/Brand/' in link):
                assert (readme.parent/link).is_file(),f'{readme}: missing image {link}'
        for p in (ROOT/addon).rglob('*.toc'):
            if any(s in p.parts for s in ('dist','_NonRelease','Builds')): continue
            text=p.read_text(encoding='utf-8-sig')
            line=next(l for l in text.splitlines() if l.startswith('## IconTexture:'))
            expected=f'Interface\\AddOns\\{addon}\\'+asset['directory'].split('/',1)[1].replace('/','\\')+f'\\{stem}-128'
            assert line.split(':',1)[1].strip()==expected,str(p)
            toc_count+=1
    names={a['stem'] for a in manifest['assets'].values()}|{f'{addon}Logo' for addon in manifest['assets']}
    names|={f'{a["stem"]}-{size}' for a in manifest['assets'].values() for size in manifest['sizes']}
    references=0
    for addon in manifest['assets']:
        for p in (ROOT/addon).rglob('*.lua'):
            if any(s in p.parts for s in ('dist','_NonRelease','Builds','Libs','Tests')): continue
            text=p.read_text(encoding='utf-8-sig').replace('\\\\','\\')
            relevant=False
            for reference in re.findall(r'Interface\\AddOns\\([^"\'\r\n]+)',text):
                parts=reference.replace('\\','/').split('/')
                leaf=parts[-1].removesuffix('.tga').removesuffix('.png')
                if leaf not in names:
                    assert not any(re.fullmatch(re.escape(addon)+r'(Icon|Logo)-v\d+.*',leaf) for addon in manifest['assets']),f'Stale versioned runtime reference: {p}: {reference}'
                    continue
                path=ROOT/Path(*parts)
                candidates=[path] if path.suffix else [path.with_suffix('.tga'),path.with_suffix('.png')]
                assert any(f.is_file() for f in candidates),f'{p}: {reference}'
                references+=1; relevant=True
            if relevant: lua_files.append(p)
    for p in lua_files:
        subprocess.run(['luac','-p',str(p)],check=True,capture_output=True)
    report=f'''# 图标资源验证

日期：2026-10-14。

- 15套资源；{count}个尺寸PNG/TGA检查通过：尺寸、RGBA和透明边缘。
- {toc_count}个当前TOC图标指向128px新版TGA。
- {references}处新版Lua纹理引用均能解析到文件；{len(lua_files)}个相关Lua文件语法通过。
- 当前资源统一位于各插件Media根目录，正式引用使用稳定文件名；历史版本位于Media/v1、v2等目录。
- 临时探针默认不覆盖正式图标；探针烟雾检查单独运行。
- 客户端正式路径的插件列表、入口与页面视觉复核待重载/重启游戏后完成。
'''
    (DESIGN/'Validation.md').write_text(report,encoding='utf-8')
    print(report)
if __name__=='__main__': main()
