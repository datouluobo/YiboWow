"""Export the approved YiboMail artwork with clean alpha and verify every file."""
from pathlib import Path
from PIL import Image
import json
import shutil

HERE = Path(__file__).resolve().parent
MEDIA = HERE.parents[2] / "YiboMail" / "Media"
SOURCE = HERE / "stage5-E-style-source-draft.png"
SIZES = (24, 32, 64, 128, 512, 1024)


def clean_alpha(image):
    image = image.convert("RGBA")
    pixels = image.load()
    w, h = image.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if a <= 8 or x in (0, w - 1) or y in (0, h - 1):
                pixels[x, y] = (0, 0, 0, 0)
    # Remove isolated alpha specks in native small icons, preserving connected edges.
    if w in (24, 32):
        isolated = []
        for y in range(1, h - 1):
            for x in range(1, w - 1):
                if pixels[x, y][3] and not any(
                    pixels[x + dx, y + dy][3]
                    for dy in (-1, 0, 1) for dx in (-1, 0, 1) if dx or dy
                ):
                    isolated.append((x, y))
        for x, y in isolated:
            pixels[x, y] = (0, 0, 0, 0)
    return image


def verify(file, size):
    with Image.open(file) as saved:
        image = saved.convert("RGBA")
        assert image.size == (size, size), file
        alpha = image.getchannel("A")
        edge = list(alpha.crop((0, 0, size, 1)).tobytes())
        edge += list(alpha.crop((0, size - 1, size, size)).tobytes())
        edge += list(alpha.crop((0, 0, 1, size)).tobytes())
        edge += list(alpha.crop((size - 1, 0, size, size)).tobytes())
        assert max(edge) == 0, file
        assert alpha.getextrema() == (0, 255), file
        return {"file": str(file.relative_to(MEDIA)), "size": size, "mode": saved.mode,
                "edgeAlphaMax": max(edge), "format": saved.format}


def main():
    MEDIA.mkdir(parents=True, exist_ok=True)
    source = Image.open(SOURCE).convert("RGBA")
    reports = []
    for size in SIZES:
        image = clean_alpha(source.resize((size, size), Image.Resampling.LANCZOS))
        for ext in ("png", "tga"):
            file = MEDIA / f"YiboMailIcon-v1-{size}.{ext}"
            image.save(file)
            reports.append(verify(file, size))
        with Image.open(MEDIA / f"YiboMailIcon-v1-{size}.png") as png, Image.open(MEDIA / f"YiboMailIcon-v1-{size}.tga") as tga:
            assert png.convert("RGBA").tobytes() == tga.convert("RGBA").tobytes(), size

    aliases = {"YiboMailIcon-v1.png": (512, "png"), "YiboMailIcon-v1.tga": (128, "tga"),
               "YiboMailLogo-v1.png": (1024, "png"), "YiboMailMinimapIcon-v1.png": (32, "png"),
               "YiboMailMinimapIcon-v1.tga": (32, "tga")}
    for name, (size, ext) in aliases.items():
        target = MEDIA / name
        shutil.copyfile(MEDIA / f"YiboMailIcon-v1-{size}.{ext}", target)
        reports.append(verify(target, size))

    skeleton = (HERE / "stage3-E-regular-hex-draft.svg").read_text(encoding="utf-8")
    skeleton = skeleton.replace("YiboMail E：正六边形外框骨架，待确认", "YiboMail v1：可编辑正六边形骨架")
    skeleton = skeleton.replace("信封、封口与封蜡沿用已确认路径。", "信封、封口与封蜡为可编辑路径；手绘材质成品见同版本 PNG/TGA。")
    (MEDIA / "YiboMailIcon-v1-master.svg").write_text(skeleton, encoding="utf-8")
    report = {"version": "v1", "status": "已完成", "source": str(SOURCE),
              "gameTexture": "YiboMailIcon-v1.tga", "gameTextureSize": 128,
              "alphaCleanupThreshold": 8, "files": reports,
              "svg": "YiboMailIcon-v1-master.svg", "pngTgaPixelEquivalence": True}
    (HERE / "v1-export-checks.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"media": str(MEDIA), "rasterFiles": len(reports), "sizes": SIZES,
                      "allEdgesTransparent": True, "pngTgaPixelEquivalence": True}, ensure_ascii=False))


if __name__ == "__main__":
    main()
