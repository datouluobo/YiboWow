"""Validate Mail archives and replay clean/retained-file overlay installations."""
import hashlib
import json
import subprocess
import sys
import zipfile
from pathlib import Path

source, packages, previous, output = (Path(p).resolve() for p in sys.argv[1:5])
lua = sys.argv[5]
cf = next(packages.glob("YiboMail-mists-v1.2.22-api1-curseforge.zip"))
gh = next(packages.glob("YiboMail-mists-v1.2.22-api1-src.*-github.zip"))
with zipfile.ZipFile(cf) as runtime, zipfile.ZipFile(gh) as public:
    names = runtime.namelist()
    assert len(names) == len(set(names))
    assert all(n.startswith("YiboMail/") and "_NonRelease/" not in n and "/Forever/" not in n for n in names)
    assert [n for n in names if n.endswith(".toc")] == ["YiboMail/YiboMail.toc"]
    assert names.count("YiboMail/Mists/TransferMigration.lua") == 1
    manifest = json.loads(runtime.read("YiboMail/YiboReleaseManifest.json"))
    public_manifest = json.loads(public.read("YiboMail/YiboReleaseManifest.json"))
    assert manifest["sourceSHA256"] == public_manifest["sourceSHA256"]
    assert set(names) == {"YiboMail/" + f for f in manifest["files"]} | {"YiboMail/YiboReleaseManifest.json"}
    assert all("_NonRelease/" not in n for n in public.namelist())
    for name in names:
        if name.endswith("YiboReleaseManifest.json"):
            continue
        assert runtime.read(name) == (source / name).read_bytes(), name
        assert runtime.read(name) == public.read(name), name
    old_names = set(zipfile.ZipFile(previous).namelist())
    residual = sorted(old_names - set(names))
    for mode in ("clean", "overlay"):
        destination = output / mode
        assert not destination.exists(), destination
        destination.mkdir(parents=True)
        if mode == "overlay":
            with zipfile.ZipFile(previous) as old:
                for name in old.namelist():
                    assert (destination / name).resolve().is_relative_to(destination.resolve())
                old.extractall(destination)
        runtime.extractall(destination)
        toc = (destination / "YiboMail/YiboMail.toc").read_text(encoding="utf-8-sig")
        assert "## Version: 1.2.22-api1" in toc
        files = [s.strip() for s in toc.splitlines() if s.strip() and not s.lstrip().startswith("#")]
        assert len(files) == len(set(files))
        assert files.count("Mists/TransferMigration.lua") == 1
        assert all((destination / "YiboMail" / f).is_file() for f in files)
        wrapper = output / (mode + ".lua")
        prefix = destination.as_posix() + "/"
        test = (source / "_NonRelease/MailTransitInvestigation/LegacyMigrationSpec.lua").as_posix()
        wrapper.write_text("local original = dofile\nfunction dofile(path)\n"
                           "if path:match('^YiboMail/') then return original(" + json.dumps(prefix) + " .. path) end\n"
                           "return original(path) end\ndofile(" + json.dumps(test) + ")\n", encoding="utf-8")
        subprocess.run([lua, str(wrapper.resolve())], cwd=source, check=True)
        print("PASS:", mode, "package load and legacy migration")
report = {"version": "1.2.22-api1", "sourceSHA256": manifest["sourceSHA256"],
          "clean": "passed", "retainedFileOverlay": "passed", "residualPaths": residual,
          "archives": {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in (cf, gh)}}
(output / "Report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps(report, indent=2))
