import argparse
import json
from pathlib import Path

from engine import TomatoDetector
import cv2
import numpy as np

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description="读取一张图片，在 CPU 上推理并输出 JSON")
parser.add_argument("image", type=Path)
args = parser.parse_args()
image = cv2.imdecode(np.fromfile(args.image, dtype=np.uint8), cv2.IMREAD_COLOR)
if image is None:
    parser.error("无法读取图片")
result = TomatoDetector(root / "models").predict(image)
print(json.dumps(result, ensure_ascii=False, indent=2))
