"""Validate and merge a generated V0.6 asset increment without overwriting existing art."""
import hashlib
import json
import pathlib
import struct
import sys
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
PREFIX = "assets/generated/hd/"
SOURCE = "art_sources/v06/"
DELTA = "V06_ASSET_MANIFEST.delta.json"


def fail(message):
    raise SystemExit(message)


def main():
    if len(sys.argv) != 2:
        fail("Usage: python3 tools/import_v06_art.py <asset-pack.zip>")
    archive = pathlib.Path(sys.argv[1]).expanduser()
    manifest_path = ROOT / "V06_ASSET_MANIFEST.json"
    manifest = json.loads(manifest_path.read_text())
    pending = {}
    with zipfile.ZipFile(archive) as z:
        names = z.namelist()
        if len(names) != len(set(names)) or z.testzip() is not None:
            fail("Invalid ZIP integrity or duplicate paths")
        delta = json.loads(z.read(DELTA))
        if not isinstance(delta, dict) or not delta:
            fail("Empty incremental manifest")
        if set(delta) != {name for name in names if name.startswith(PREFIX)}:
            fail("Runtime PNGs must match the incremental manifest exactly")
        for name in names:
            if name in (DELTA, "README.txt"):
                continue
            rel = pathlib.PurePosixPath(name)
            if rel.is_absolute() or ".." in rel.parts or not name.endswith(".png") or not name.startswith((PREFIX, SOURCE)):
                fail(f"Unexpected archive entry: {name}")
            target = ROOT / name
            if not target.resolve().is_relative_to(ROOT.resolve()):
                fail(f"Unsafe target: {name}")
            raw = z.read(name)
            if raw[:8] != bytes.fromhex("89504e470d0a1a0a") or raw[12:16] != b"IHDR":
                fail(f"Not a PNG: {name}")
            width, height, depth, color = struct.unpack(">IIBB", raw[16:26])
            if name.startswith(PREFIX):
                meta = delta[name]
                if depth != 8 or color not in (2, 6) or min(width, height) < 128:
                    fail(f"Not full-color native-size PNG: {name}")
                if name.startswith(PREFIX + "animations/") and (width % 4 or height != width // 4 * 5 or width // 4 < 128):
                    fail(f"Invalid action atlas: {name}")
                if name.startswith(tuple(PREFIX + part for part in ("animations/", "actors/", "biome/", "weapons/", "vfx/", "props/", "enemy_animations/"))) and color != 6:
                    fail(f"RGBA required: {name}")
                if (width, height) != (meta.get("width"), meta.get("height")) or hashlib.sha256(raw).hexdigest() != meta.get("sha256"):
                    fail(f"Manifest mismatch: {name}")
                if name in manifest and manifest[name] != meta:
                    fail(f"Refusing to overwrite manifest entry: {name}")
            if target.exists() and target.read_bytes() != raw:
                fail(f"Refusing to overwrite existing file: {name}")
            pending[target] = raw
    # Validate the entire increment before writing any files.
    for target, raw in pending.items():
        if not target.exists():
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(raw)
    manifest.update(delta)
    temporary = manifest_path.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    temporary.replace(manifest_path)
    print(f"Imported {len(delta)} verified runtime PNGs; manifest now has {len(manifest)} entries.")


if __name__ == "__main__":
    main()
