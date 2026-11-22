"""把指定训练权重导出到其所在目录，不覆盖发布模型。"""
import argparse,os
from pathlib import Path
def main():
    root=Path(__file__).resolve().parents[1]
    parser=argparse.ArgumentParser()
    parser.add_argument('weights',help='本次训练输出的 best.pt 路径')
    args=parser.parse_args()
    os.environ['YOLO_CONFIG_DIR']=str(root/'outputs/yolo-config')
    os.environ['YOLO_AUTOINSTALL']='false'
    os.environ.pop('ULTRALYTICS_API_KEY',None)
    from ultralytics import YOLO
    path=YOLO(args.weights).export(format='onnx',imgsz=640,batch=1,dynamic=False,simplify=False,opset=17,device='cpu')
    print(path)
if __name__=='__main__':main()
