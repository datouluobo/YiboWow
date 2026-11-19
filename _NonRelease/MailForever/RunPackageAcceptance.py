"""Verify generated packages and run real Lua manifests; never change a client install."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile

workspace = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--candidate', type=Path, default=Path('_NonRelease/MailForever/AcceptanceCandidate-20261118'))
parser.add_argument('--previous-candidate', type=Path)
parser.add_argument('--verify-current-runtime', action='store_true')
options = parser.parse_args()
candidate = (workspace / options.candidate).resolve()
run = Path(tempfile.mkdtemp(prefix='Run-', dir=candidate))
results = {'kind': 'offline-package-acceptance', 'clientValidated': False, 'packages': [], 'cases': []}


def extract(package, destination):
    with zipfile.ZipFile(package) as archive:
        for entry in archive.infolist():
            target = (destination / entry.filename).resolve()
            if not target.is_relative_to(destination.resolve()):
                raise ValueError('Package path outside extraction directory')
        archive.extractall(destination)


for addon in ('YiboMail', 'YiboVault'):
    for target in ('Forever', 'Mists'):
        package, = (candidate / addon / target).glob('*.zip')
        extract(package, run / 'clean' / target)
        with zipfile.ZipFile(package) as archive:
            manifest = json.loads(archive.read(f'{addon}/YiboReleaseManifest.json'))
            actual = {entry.filename for entry in archive.infolist() if not entry.is_dir()}
            expected = {f'{addon}/{name}' for name in manifest['files']} | {f'{addon}/YiboReleaseManifest.json'}
            assert actual == expected, 'Manifest payload mismatch'
            assert manifest['target'] == target
            assert {name for name in actual if name.endswith('.toc')} == {f'{addon}/{addon}.toc'}
            other = 'Mists' if target == 'Forever' else 'Forever'
            assert not any(name.startswith(f'{addon}/{other}/') for name in actual)
            toc = archive.read(f'{addon}/{addon}.toc').decode('utf-8-sig')
            references = [line.strip().replace('\\', '/') for line in toc.splitlines() if line.strip().endswith('.lua')]
            assert len(references) == len(set(references)), 'Duplicate runtime load'
            assert all(f'{addon}/{name}' in actual for name in references)
            if options.verify_current_runtime:
                for name in references:
                    assert archive.read(f'{addon}/{name}') == (workspace / addon / name).read_bytes(), f'Runtime differs from current source: {addon}/{name}'
                source_toc = (workspace / addon / f'{addon}_{target}.toc').read_text(encoding='utf-8-sig')
                source_references = [line.strip().replace('\\', '/') for line in source_toc.splitlines() if line.strip().endswith('.lua')]
                assert references == source_references, 'Package load order differs from current target source'
            results['packages'].append({'addon': addon, 'target': target,
                'path': str(package.relative_to(workspace)), 'sha256': hashlib.sha256(package.read_bytes()).hexdigest(),
                'sourceSHA256': manifest['sourceSHA256'], 'payloadVerified': True,
                'currentRuntimeVerified': options.verify_current_runtime})

cases = [('Forever', None), ('Mists', None),
         ('Forever', workspace / 'Builds/YiboMail-forever-v0.1.5-api1-curseforge.zip'),
         ('Mists', workspace / 'Builds/YiboMail-mists-v1.3.5-api1-curseforge.zip'),
         ('Mists', workspace / 'Builds/Archive/YiboMail/YiboMail-mists-v1.3.4-api1-curseforge.zip')]
if options.previous_candidate:
    previous = (workspace / options.previous_candidate).resolve()
    for target in ('Forever', 'Mists'):
        package, = (previous / 'YiboMail' / target).glob('*.zip')
        cases.append((target, package))
for index, (target, old) in enumerate(cases):
    root = run / 'clean' / target / 'YiboMail'
    baseline = '-'
    preserved = []
    if old:
        base = run / f'baseline-{index}'
        extract(old, base)
        baseline = str(base / 'YiboMail')
        overlay = run / f'overlay-{index}'
        shutil.copytree(base, overlay)
        old_files = {path.relative_to(base).as_posix(): path.read_bytes() for path in base.rglob('*') if path.is_file()}
        package, = (candidate / 'YiboMail' / target).glob('*.zip')
        with zipfile.ZipFile(package) as archive:
            new_files = set(archive.namelist())
        extract(package, overlay)
        for name, content in old_files.items():
            if name not in new_files:
                assert (overlay / name).read_bytes() == content, 'Overlay removed or altered an old residual'
                preserved.append(name)
        root = overlay / 'YiboMail'
    command = ['lua', '_NonRelease/MailForever/PackageAcceptance.lua', str(root), target, baseline,
               str(run / 'clean' / target / 'YiboVault')]
    completed = subprocess.run(command, cwd=workspace, capture_output=True, text=True)
    result = {'target': target, 'baseline': str(old.relative_to(workspace)) if old else None,
              'baselineSHA256': hashlib.sha256(old.read_bytes()).hexdigest() if old else None,
              'retainedFiles': preserved, 'exitCode': completed.returncode,
              'output': completed.stdout + completed.stderr}
    results['cases'].append(result)
    print(result['output'], end='')
    if completed.returncode:
        (run / 'Results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding='utf-8')
        raise SystemExit(completed.returncode)
(run / 'Results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding='utf-8')
print(f'Package evidence: {run / "Results.json"}')
