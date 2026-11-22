"""Local-only transfer-learning experiments, no telemetry or cloud upload."""
import os, sys, json, shutil
from pathlib import Path
W=Path(__file__).resolve().parent
os.environ["YOLO_CONFIG_DIR"]=str(W/"yolo_settings")
os.environ["WANDB_DISABLED"]="true"
os.environ.pop("ULTRALYTICS_API_KEY",None)
from ultralytics import YOLO, settings
settings.update({"sync":False,"wandb":False,"comet":False,"mlflow":False,"clearml":False})

def run(name,epochs,freeze):
    data_root=W.parent/"data"
    (W/"data_absolute.yaml").write_text(f"path: {data_root.as_posix()}\n"+(data_root/"dataset.yaml").read_text(encoding="utf-8"),encoding="utf-8")
    model=YOLO(str(W/"sources/yolov8n.pt"))
    return model.train(data=str(W/"data_absolute.yaml"),epochs=epochs,imgsz=640,batch=12,
        device=0,workers=0,seed=20261021,deterministic=True,project=str(W/"runs"),
        name=name,exist_ok=True,optimizer="AdamW",lr0=0.001,freeze=freeze,
        hsv_h=0.0,hsv_s=0.25,hsv_v=0.25,close_mosaic=min(5,epochs),
        cache=True,plots=True,amp=True,patience=15)

if __name__=="__main__":
    mode=sys.argv[1] if len(sys.argv)>1 else "smoke"
    if mode=="smoke":run("smoke",1,10)
    elif mode=="train":
        run("baseline_frozen",12,10)
        run("finetune",50,0)
    else:raise ValueError(mode)
