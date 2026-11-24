"""Reproducible project-local Latin/Simplified Chinese subset, OFL 1.1.
Usage: python tools/build_ui_font.py /path/to/NotoSansCJKsc-Regular.otf
Requires fonttools==4.61.1. Source: notofonts/noto-cjk tag Sans2.004.
"""
import hashlib
import sys
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools import subset

root = Path(__file__).resolve().parents[1]
source = Path(sys.argv[1])
assert hashlib.sha256(source.read_bytes()).hexdigest() == "2c76254f6fc379fddfce0a7e84fb5385bb135d3e399294f6eeb6680d0365b74b"
font = TTFont(source, recalcTimestamp=False)
chars = set(range(32, 127)) | set(range(160, 256)) | set(map(ord, "→←↑↓★☆∞×−·…—–✓√△▲▼○●％＋－"))
for folder in ("scripts", "scenes", "resources", "data"):
    for p in (root / folder).rglob("*"):
        if p.suffix in (".gd", ".tscn", ".tres", ".json", ".csv"):
            chars.update(map(ord, p.read_text(encoding="utf-8")))
cmap = font.getBestCmap()
required = {c for c in chars if 0x3400 <= c <= 0x9fff or c in range(32, 127) or c in map(ord, "→←★∞×·")}
assert required <= cmap.keys(), sorted(required - cmap.keys())
options = subset.Options()
options.name_IDs = ["*"]
options.name_languages = ["*"]
options.recalc_timestamp = False
sub = subset.Subsetter(options=options)
sub.populate(unicodes=chars & cmap.keys())
sub.subset(font)
# Rename derivative, retain original copyright and license name entries.
for record in font["name"].names:
    new = {1:"Sprout UI Sans",2:"Regular",3:"SproutUISans-Regular-2.004",4:"Sprout UI Sans Regular",6:"SproutUISans-Regular",16:"Sprout UI Sans",17:"Regular"}.get(record.nameID)
    if new is not None:
        record.string = new
if "CFF " in font:
    cff = font["CFF "].cff
    cff.fontNames = ["SproutUISans-Regular"]
    cff.topDictIndex[0].FamilyName = "Sprout UI Sans"
    cff.topDictIndex[0].FullName = "Sprout UI Sans Regular"
out = root / "assets/ui/fonts/SproutUISans-Regular.otf"
font.save(out)
assert required <= TTFont(out).getBestCmap().keys()
print(f"UI font: {out.stat().st_size} bytes, {len(required)} required codepoints")
