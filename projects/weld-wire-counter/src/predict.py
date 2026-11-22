import argparse
import json
from pathlib import Path

from engine import Detector, read_image

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description="读取一张图片，在 CPU 上推理并输出 JSON")
parser.add_argument("image", type=Path)
args = parser.parse_args()
result = Detector(root / "models/best.onnx").predict(read_image(args.image))
print(json.dumps(result, ensure_ascii=False, indent=2))
