from pathlib import Path
import hashlib
import json
import re
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[2]
RUN = Path(__file__).resolve().parent
SOURCE = RUN / 'Source'
plans = json.loads((RUN / 'BuildPlans.json').read_text(encoding='utf-8-sig'))
old_names = {
    'YiboCore': 'YiboCore-mists-v1.12.8-api13-curseforge.zip',
    'YiboCrafting': 'YiboCrafting-v1.2.0-curseforge.zip',
    'YiboTaskHub': 'YiboTaskHub-v0.6.0-curseforge.zip',
}
record = {'packages': [], 'installations': {}}
for plan in plans:
    addon = plan['Addon']
    old = ROOT / 'Builds' / 'Archive' / addon / old_names[addon]
    assert old.is_file(), old
    for channel in ['CurseForge', 'GitHub']:
        package = Path(plan[channel])
        with zipfile.ZipFile(package) as z:
            assert all(n.startswith(addon + '/') and '..' not in Path(n).parts for n in z.namelist())
            assert all('/_NonRelease/' not in n and '/WTF/' not in n and '/Builds/' not in n for n in z.namelist())
            manifest = json.loads(z.read(addon + '/YiboReleaseManifest.json'))
            assert next(t for t in manifest['registeredTargets'] if t['target'] == 'Mists')['version'] == plan['Version'], (addon, manifest)
            if channel == 'CurseForge':
                tocs = [n for n in z.namelist() if n.endswith('.toc')]
                assert tocs == [addon + '/' + addon + '.toc'], tocs
        record['packages'].append({'addon': addon, 'version': plan['Version'], 'channel': channel,
            'path': str(package), 'sha256': hashlib.sha256(package.read_bytes()).hexdigest()})
    for mode in ['Clean', 'Overlay']:
        install = RUN / mode
        install.mkdir(exist_ok=True)
        if mode == 'Overlay':
            with zipfile.ZipFile(old) as z: z.extractall(install)
        with zipfile.ZipFile(plan['CurseForge']) as z:
            z.extractall(install)
            for name in z.namelist():
                if not name.endswith('/'):
                    assert (install / name).read_bytes() == z.read(name), name
        toc = install / addon / (addon + '.toc')
        text = toc.read_text(encoding='utf-8-sig')
        assert re.search(r'^## Version:\s*' + re.escape(plan['Version']) + r'\s*$', text, re.M)
        for line in text.splitlines():
            if line.strip() and not line.startswith('#'):
                path = toc.parent / line.strip().replace('\\', '/')
                assert path.is_file(), path
                if path.suffix == '.lua': subprocess.run(['luac', '-p', str(path)], check=True, capture_output=True)
        if addon == 'YiboCrafting':
            assert 'Mists/RecipeCatalog.lua' in text and 'Mists/GoalTargets.lua' in text
        if addon == 'YiboTaskHub': assert 'Common/Goals.lua' in text

for mode in ['Clean', 'Overlay']:
    install = RUN / mode
    runner = RUN / (mode + '-Replay.lua')
    runner.write_text('''local install = %s
local originalDofile, originalLoadfile = dofile, loadfile
local loaded = {}
local function Translate(path)
    if path:match("^YiboCore/") or path:match("^YiboCrafting/") or path:match("^YiboTaskHub/") then
        if not path:find("/_NonRelease/", 1, true) and not path:find("/Tests/", 1, true) then
            local full = install .. "/" .. path
            local handle = assert(io.open(full, "rb"), "missing installed runtime: " .. path)
            handle:close(); loaded[path] = true; return full
        end
    end
    return path
end
dofile = function(path) return originalDofile(Translate(path)) end
loadfile = function(path) return originalLoadfile(Translate(path)) end
dofile("_NonRelease/TaskGoalIntegration/CraftingCastSpec.lua")
assert(loaded["YiboCrafting/Mists/GoalTargets.lua"] and loaded["YiboTaskHub/Common/Goals.lua"])
assert(not loaded["YiboCrafting/GoalTargets.lua"] and not loaded["YiboCrafting/RecipeCatalog.lua"] and not loaded["YiboTaskHub/Goals.lua"])
assert(YiboCore.VERSION == "1.12.9" and YiboTaskHub.VERSION == "0.6.1")
print("Installed package replay passed: current paths only, completion history and markers")
''' % json.dumps(install.as_posix()), encoding='utf-8')
    result = subprocess.run(['lua', str(runner)], cwd=SOURCE, text=True, capture_output=True)
    assert result.returncode == 0, result.stdout + result.stderr
    leftovers = []
    for name in ['YiboCrafting/GoalTargets.lua', 'YiboCrafting/RecipeCatalog.lua', 'YiboTaskHub/Goals.lua']:
        if (install / name).is_file(): leftovers.append(name)
    if mode == 'Overlay': assert len(leftovers) == 3, leftovers
    record['installations'][mode] = {'passed': True, 'retainedLegacyFiles': leftovers, 'replay': result.stdout}
(RUN / 'Verification.json').write_text(json.dumps(record, indent=2, ensure_ascii=False), encoding='utf-8')
print('Six archives verified; clean and preserved-file overlay package replays passed.')
