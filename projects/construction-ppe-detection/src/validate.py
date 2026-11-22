"""可选重测：不训练，读取随包权重和保留测试集。"""
import os,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
os.environ['YOLO_CONFIG_DIR']=str(ROOT/'training_settings')
os.environ['YOLO_OFFLINE']='true'
if __name__=='__main__':
    import yaml
    from ultralytics import YOLO
    cfg=yaml.safe_load((ROOT/'data/data.yaml').read_text('utf-8'))
    cfg['path']=str(ROOT/'data')
    target=ROOT/'data_runtime.yaml'
    target.write_text(yaml.safe_dump(cfg),encoding='utf-8')
    results={}
    for name in ['early','final']:
        m=YOLO(str(ROOT/'models'/f'{name}.pt')).val(
            data=str(target),split='test',imgsz=640,batch=12,
            rect=False,nms=False,conf=.001,device='cpu',workers=0,
            project=str(ROOT/'validation_runs'),name=name,plots=True)
        results[name]={'mAP50':float(m.box.map50),
                       'mAP50_95':float(m.box.map),
                       'per_class_AP50':m.box.ap50.tolist()}
    (ROOT/'retest_metrics.json').write_text(
        json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(results,indent=2))
