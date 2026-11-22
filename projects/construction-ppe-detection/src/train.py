"""可选复现实验；现场演示直接使用随包模型，无需训练。"""
import os
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
os.environ['YOLO_CONFIG_DIR'] = str(ROOT / 'training_settings')
os.environ['YOLO_OFFLINE'] = 'true'
os.environ.pop('ULTRALYTICS_API_KEY', None)

def stop_at_twenty(trainer):
    # 保持原40轮学习率计划，在完成20轮后停止。
    if trainer.epoch + 1 >= 20:
        trainer.stop = True

if __name__ == '__main__':
    from ultralytics import YOLO, settings
    import yaml
    settings.update({'sync': False, 'wandb': False, 'mlflow': False,
                     'comet': False, 'clearml': False, 'api_key': ''})
    config = yaml.safe_load((ROOT / 'data/data.yaml').read_text('utf-8'))
    config['path'] = str(ROOT / 'data')
    target = ROOT / 'data_runtime.yaml'
    target.write_text(yaml.safe_dump(config), encoding='utf-8')
    model = YOLO(str(ROOT / 'models/yolo26n.pt'))
    model.add_callback('on_fit_epoch_end', stop_at_twenty)
    model.train(data=str(target), epochs=40, imgsz=640, batch=12,
                device=0, workers=2, seed=42, deterministic=True,
                optimizer='AdamW', lr0=.001, lrf=.01, patience=12,
                close_mosaic=5, amp=True, nms=False,
                project=str(ROOT / 'training_runs'), name='ppe',
                save_period=5, plots=True, verbose=False)
