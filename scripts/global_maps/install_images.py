"""render_world.py が out/ に書き出した古地図（PNG）を、iOS のアセットと Web の公開フォルダに JPEG で置く。

    python3 install_images.py prague vienna ...

ファイル名は catalog/old_maps.json の imageAssetName（iOS）と webImage（Web）から決める。
out/<name>.png の <name> は webImage の「old_map_<name>.jpg」の <name> と同じ。
"""
import json
import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).parent
ROOT = HERE.parent.parent
ASSETS = ROOT / "Komap/Resources/Assets.xcassets"
WEB = ROOT / "web/public/old-maps"

CONTENTS = {
    "images": [
        {"filename": None, "idiom": "universal", "scale": "1x"},
        {"idiom": "universal", "scale": "2x"},
        {"idiom": "universal", "scale": "3x"},
    ],
    "info": {"author": "xcode", "version": 1},
}


def main(names):
    maps = json.loads((ROOT / "catalog/old_maps.json").read_text())["maps"]
    by_name = {m["webImage"].removeprefix("old_map_").removesuffix(".jpg"): m for m in maps if m.get("webImage")}
    for name in names:
        entry = by_name.get(name)
        if not entry:
            raise SystemExit(f"catalog/old_maps.json に webImage が old_map_{name}.jpg の古地図がありません")
        source = HERE / "out" / f"{name}.png"
        if not source.exists():
            raise SystemExit(f"{source} がありません。先に render_world.py {name} を実行してください")
        image = Image.open(source).convert("RGB")

        imageset = ASSETS / f"{entry['imageAssetName']}.imageset"
        imageset.mkdir(exist_ok=True)
        image.save(imageset / entry["webImage"], "JPEG", quality=85, optimize=True, progressive=True)
        contents = json.loads(json.dumps(CONTENTS))
        contents["images"][0]["filename"] = entry["webImage"]
        (imageset / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")

        image.save(WEB / entry["webImage"], "JPEG", quality=85, optimize=True, progressive=True)
        print("installed", name, "→", imageset.name, "/", entry["webImage"])


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    main(sys.argv[1:])
