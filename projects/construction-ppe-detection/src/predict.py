import argparse
import json
from pathlib import Path

from engine import Engine
from PIL import Image, ImageOps

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description="读取一张图片，在 CPU 上推理并输出 JSON")
parser.add_argument("image", type=Path)
args = parser.parse_args()
with Image.open(args.image) as source:
    image = ImageOps.exif_transpose(source).convert("RGB")
result = Engine(root / "models/final.onnx").predict(image)
print(json.dumps(result, ensure_ascii=False, indent=2))
