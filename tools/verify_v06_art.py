"""Fail closed: no V0.6 acceptance without real HD PNGs and hash manifest."""
import hashlib
import json
import pathlib
import struct
import sys

root = pathlib.Path(__file__).resolve().parents[1]
prefix = "assets/generated/hd/"
manifest_path = root / "V06_ASSET_MANIFEST.json"
manifest = json.loads(manifest_path.read_text()) if manifest_path.is_file() else {}
required = {f"terrain/{name}.png": 512 for name in ("classic", "forest", "night", "swamp")}
required.update({f"animations/hero_{i}.png": 512 for i in range(5)})
required.update({f"actors/actor_{i}.png": 128 for i in range(6)})
required.update({f"biome/biome_{i}.png": 128 for i in range(9)})
required.update({f"weapons/weapon_{i}.png": 128 for i in range(8)})
required["menu/background.png"] = 720
required.update({f"props/{name}/prop_{i}.png": 128 for name in ("classic", "forest", "night", "swamp") for i in range(6)})
required.update({f"vfx/{kind}_{i}.png": 128 for kind in ("projectile", "impact", "evolution") for i in range(8)})
errors = []
for relative, minimum in required.items():
    key = prefix + relative
    path = root / key
    if not path.is_file() or key not in manifest:
        errors.append(f"Missing PNG or manifest entry: {key}")
        continue
    raw = path.read_bytes()
    if raw[:8] != b"\x89PNG\r\n\x1a\n" or raw[12:16] != b"IHDR":
        errors.append(f"Not a PNG: {key}")
        continue
    width, height, depth, color = struct.unpack(">IIBB", raw[16:26])
    meta = manifest[key]
    if min(width, height) < minimum or depth != 8 or color not in (2, 6):
        errors.append(f"Not native-size full-color RGB/RGBA: {key}")
    if relative.startswith("animations/") and (width % 4 or height != width // 4 * 5 or width // 4 < 128):
        errors.append(f"Invalid 4x5 action sheet: {key}")
    if relative.startswith(("animations/", "actors/", "biome/", "weapons/", "vfx/", "props/")) and color != 6:
        errors.append(f"Transparent RGBA required: {key}")
    if (width, height) != (meta.get("width"), meta.get("height")) or hashlib.sha256(raw).hexdigest() != meta.get("sha256"):
        errors.append(f"Manifest hash or dimensions mismatch: {key}")
    print(key, width, height)
if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)
print(f"Verified {len(required)} native-size PNGs. Visual review still required.")
