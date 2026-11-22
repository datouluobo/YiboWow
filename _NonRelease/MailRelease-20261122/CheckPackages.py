"""Inspect built CurseForge zips: hashes, manifest, content rules."""
import hashlib, json, zipfile, sys
from pathlib import Path
W = Path(r'D:\Development\YiboWow')
pkgs = [('YiboMail','Mists','Builds/YiboMail-mists-v1.4.0-api1-curseforge.zip'),
        ('YiboMail','Forever','Builds/YiboMail-forever-v0.3.0-api1-curseforge.zip'),
        ('YiboVault','Mists','Builds/YiboVault-mists-v1.3.0-api1-curseforge.zip'),
        ('YiboVault','Forever','Builds/YiboVault-forever-v0.7.0-api1-curseforge.zip')]
bad_markers = ('_NonRelease', '/Tests/', '/WTF/', 'Spec.lua', '.md', 'TocHint')
ok = True
for addon, target, rel in pkgs:
    p = W / rel
    data = p.read_bytes()
    with zipfile.ZipFile(p) as z:
        names = [n for n in z.namelist() if not n.endswith('/')]
        man = json.loads(z.read(f'{addon}/YiboReleaseManifest.json'))
        toc = z.read(f'{addon}/{addon}.toc').decode('utf-8-sig')
        tocs = [n for n in names if n.lower().endswith('.toc')]
        tops = {n.split('/')[0] for n in names}
        other = 'Forever' if target == 'Mists' else 'Mists'
        refs = [l.strip().replace('\\','/') for l in toc.splitlines() if l.strip() and not l.startswith('#')]
        missing = [r for r in refs if f'{addon}/{r}' not in names]
        others = [n for n in names if n.startswith(f'{addon}/{other}/')]
        bad = [n for n in names if any(m in n for m in bad_markers)]
        expected = {f'{addon}/{n}' for n in man['files']} | {f'{addon}/YiboReleaseManifest.json'}
        unlisted = sorted(set(names) ^ expected)
        # Lua files in package not referenced by TOC (allowed only if resources)
        unref = [n for n in names if n.endswith('.lua') and n[len(addon)+1:] not in refs]
        ver = [l for l in toc.splitlines() if l.startswith('## Version') or l.startswith('## Interface') or l.startswith('## SavedVariables')]
        tinfo = [t for t in man.get('registeredTargets', []) if t.get('target') == target] or man.get('registeredTargets')
        print(f'== {addon} {target}: {p.name}')
        print(f'   size={len(data)} sha256={hashlib.sha256(data).hexdigest().upper()}')
        print(f'   manifest target={man.get("target")} version={man.get("version")} sourceSHA256={man.get("sourceSHA256")}')
        for t in man.get('registeredTargets', []):
            print('   registered:', {k: t.get(k) for k in ('target','version','publicAPI','minimumCoreAPI','interface','validationState')})
        print(f'   files={len(names)} tops={sorted(tops)} tocs={tocs} tocRefs={len(refs)} missingRefs={missing}')
        print(f'   otherTargetFiles={len(others)} forbidden={bad} manifestMismatch={unlisted} unreferencedLua={unref}')
        print('   ' + ' | '.join(ver))
        good = tops == {addon} and tocs == [f'{addon}/{addon}.toc'] and not missing and not others and not bad and not unlisted and not unref and man.get('target') == target
        print('   CONTENT_OK' if good else '   CONTENT_FAIL')
        ok = ok and good
sys.exit(0 if ok else 1)
