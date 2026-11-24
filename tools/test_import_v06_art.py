"""Exercise imports in isolated temporary roots; never add fixtures to the game."""
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest
import zipfile
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("asset_import", Path(__file__).with_name("import_v06_art.py"))
importer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(importer)


class ImportTests(unittest.TestCase):
    def test_merge_and_refuse_conflict(self):
        original = importer.ROOT / "assets/generated/hd/animations/hero_0.png"
        raw = original.read_bytes()
        width, height = struct.unpack(">II", raw[16:24])
        key = importer.PREFIX + "animations/hero_3.png"
        meta = {"width": width, "height": height, "sha256": hashlib.sha256(raw).hexdigest()}
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            manifest = root / "V06_ASSET_MANIFEST.json"
            manifest.write_text(json.dumps({"existing": {"sha256": "keep"}}))
            archive = root / "test.zip"
            def write_pack(data, info):
                with zipfile.ZipFile(archive, "w") as z:
                    z.writestr(importer.DELTA, json.dumps({key: info}))
                    z.writestr(key, data)
            write_pack(raw, meta)
            with patch.object(importer, "ROOT", root), patch.object(sys, "argv", ["import", str(archive)]):
                importer.main()
                importer.main()
                self.assertEqual((root / key).read_bytes(), raw)
                self.assertEqual(json.loads(manifest.read_text())["existing"]["sha256"], "keep")
                self.assertEqual(json.loads(manifest.read_text())[key], meta)
                write_pack(raw + b"x", {**meta, "sha256": hashlib.sha256(raw + b"x").hexdigest()})
                with self.assertRaises(SystemExit):
                    importer.main()
                self.assertEqual((root / key).read_bytes(), raw)
                self.assertEqual(json.loads(manifest.read_text())[key], meta)


if __name__ == "__main__":
    unittest.main()
