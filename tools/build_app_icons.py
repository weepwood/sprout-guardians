#!/usr/bin/env python3
"""Derive native icon formats from the existing approved hero artwork."""
from pathlib import Path
from PIL import Image
import argparse
import tempfile
import subprocess

root = Path(__file__).resolve().parents[1]
source = root / "assets/generated/hd/actors/actor_0.png"
out = root / "assets/branding"
out.mkdir(exist_ok=True)
parser = argparse.ArgumentParser()
parser.add_argument("--mac", action="store_true", help="Use native iconutil to build ICNS")
args = parser.parse_args()
with Image.open(source) as original:
    image = original.convert("RGBA")
assert image.size == (512, 512)
image.save(out / "app-icon.png")
image.save(out / "app-icon.ico", sizes=[(n,n) for n in (16,24,32,48,64,128,256)])
if args.mac:
    with tempfile.TemporaryDirectory() as tmp:
        iconset = Path(tmp) / "AppIcon.iconset"
        iconset.mkdir()
        for n in (16,32,128,256,512):
            for scale in (1,2):
                suffix = "@2x" if scale == 2 else ""
                image.resize((n*scale,n*scale), Image.Resampling.LANCZOS).save(iconset / f"icon_{n}x{n}{suffix}.png")
        subprocess.run(["iconutil","-c","icns",str(iconset),"-o",str(out / "app-icon.icns")],check=True)
with Image.open(out / "app-icon.ico") as ico:
    assert (256,256) in ico.ico.sizes() and (16,16) in ico.ico.sizes()
print("Native icon derivatives generated from existing 512px hero artwork")
