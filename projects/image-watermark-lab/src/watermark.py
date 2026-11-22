import argparse
from pathlib import Path

from core import decode, embed, extract_bits, image_read, save_img


def main():
    parser = argparse.ArgumentParser(description="向 PNG 写入文字，或从水印图提取文字")
    actions = parser.add_subparsers(dest="action", required=True)
    write = actions.add_parser("embed")
    write.add_argument("image", type=Path)
    write.add_argument("text")
    write.add_argument("output", type=Path)
    read = actions.add_parser("extract")
    read.add_argument("image", type=Path)
    args = parser.parse_args()
    image = image_read(args.image.read_bytes())
    if args.action == "embed":
        if args.output.suffix.lower() != ".png":
            parser.error("输出文件请使用 PNG 扩展名")
        save_img(args.output, embed(image, args.text))
    else:
        result = decode(extract_bits(image))
        if not result["valid"]:
            parser.exit(1, "没有提取到通过校验的水印。\n")
        print(result["text"])


if __name__ == "__main__":
    main()
