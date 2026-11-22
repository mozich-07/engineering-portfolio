"""从提供的 COCO 预训练权重开始迁移学习；训练输出不覆盖交付模型。"""
import argparse, os
from pathlib import Path

def main():
    root=Path(__file__).resolve().parents[1]
    parser=argparse.ArgumentParser(description='YOLOv8n 焊丝单类别迁移学习')
    parser.add_argument('--epochs',type=int,default=100)
    parser.add_argument('--batch',type=int,default=8)
    parser.add_argument('--device',default='auto')
    parser.add_argument('--name',default='wire_seed42')
    args=parser.parse_args()
    os.environ['YOLO_CONFIG_DIR']=str(root/'outputs/yolo-config')
    os.environ['YOLO_AUTOINSTALL']='false'
    os.environ.pop('ULTRALYTICS_API_KEY',None)
    from ultralytics import YOLO, settings
    import torch,yaml
    settings.update({k:False for k in ['sync','wandb','mlflow','comet','clearml','tensorboard','neptune','dvc','raytune'] if k in settings})
    if 'api_key' in settings:settings.update({'api_key':''})
    config=root/'outputs/dataset.local.yaml';config.parent.mkdir(parents=True,exist_ok=True)
    data={'path':str((root/'data/training').resolve()),'train':'images/train','val':'images/val','names':{0:'hansi'}}
    config.write_text(yaml.safe_dump(data,allow_unicode=True),encoding='utf-8')
    device=(0 if torch.cuda.is_available() else 'cpu') if args.device=='auto' else args.device
    YOLO(root/'models/yolov8n.pt').train(
        data=str(config),epochs=args.epochs,batch=args.batch,imgsz=640,
        device=device,workers=0,cache=True,seed=42,deterministic=True,
        optimizer='AdamW',lr0=.001,patience=20,amp=False,
        project=str(root/'outputs/training'),name=args.name,exist_ok=False,plots=True)

if __name__=='__main__':main()
