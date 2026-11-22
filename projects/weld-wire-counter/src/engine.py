"""YOLOv8 single-class ONNX inference. No network or Torch dependency."""
from pathlib import Path
import csv
import json
import os
import time
import cv2
import numpy as np
import onnxruntime as ort

EXTENSIONS = {'.jpg', '.jpeg', '.png', '.bmp', '.tif', '.tiff', '.webp'}
METHODS = ['原图识别', '灰度后识别', '对比度增强后识别', '灰度滤波后识别']

def read_image(path):
    path = Path(path)
    if not path.is_file():
        raise ValueError('文件不存在')
    if path.stat().st_size > 100 * 1024**2:
        raise ValueError('图片超过 100MB，请先缩小图片')
    data = np.fromfile(str(path), dtype=np.uint8)
    img = cv2.imdecode(data, cv2.IMREAD_COLOR)
    if img is None or img.size == 0:
        raise ValueError('无法读取图片，请选择有效的 JPG、PNG 或 BMP 文件')
    if img.shape[0] * img.shape[1] > 60_000_000:
        raise ValueError('图片超过 6000 万像素，请先缩小图片')
    return img

def write_image(path, img):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    ok, buf = cv2.imencode(path.suffix or '.png', img)
    if not ok:
        raise IOError('图片编码失败')
    buf.tofile(str(path))

def processing_stages(img):
    # Work at screen resolution for educational previews; inference uses full input.
    ratio = min(1, 1000/max(img.shape[:2]))
    small = cv2.resize(img, None, fx=ratio, fy=ratio) if ratio < 1 else img.copy()
    gray = cv2.cvtColor(small, cv2.COLOR_BGR2GRAY)
    blur = cv2.GaussianBlur(gray, (5,5), 0)
    _, binary = cv2.threshold(blur, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    opened = cv2.morphologyEx(binary, cv2.MORPH_OPEN, np.ones((3,3),np.uint8))
    return [('灰度化', gray), ('高斯滤波 5 × 5', blur), ('Otsu 二值化', binary), ('形态学开运算 3 × 3', opened)]

def transform(img, method):
    if method == METHODS[3]:
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        return cv2.cvtColor(cv2.GaussianBlur(gray, (5,5), 0), cv2.COLOR_GRAY2BGR)
    if method == METHODS[1]:
        return cv2.cvtColor(cv2.cvtColor(img, cv2.COLOR_BGR2GRAY), cv2.COLOR_GRAY2BGR)
    if method == METHODS[2]:
        lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)
        lab[:,:,0] = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8,8)).apply(lab[:,:,0])
        return cv2.cvtColor(lab, cv2.COLOR_LAB2BGR)
    if method != METHODS[0]:
        raise ValueError('未知处理方法')
    return img

def nms(boxes, scores, threshold=0.7, limit=300):
    if len(boxes) == 0:
        return np.empty(0, dtype=int)
    x1,y1,x2,y2 = boxes.T
    area = np.maximum(0,x2-x1)*np.maximum(0,y2-y1)
    order = np.argsort(-scores, kind='stable')
    keep=[]
    while len(order) and len(keep)<limit:
        i=order[0]; keep.append(i); rest=order[1:]
        intersection=np.maximum(0,np.minimum(x2[i],x2[rest])-np.maximum(x1[i],x1[rest]))*np.maximum(0,np.minimum(y2[i],y2[rest])-np.maximum(y1[i],y1[rest]))
        iou=intersection/np.maximum(area[i]+area[rest]-intersection,1e-8)
        order=rest[iou<=threshold]
    return np.array(keep,dtype=int)

class Detector:
    def __init__(self, model_path):
        model_path=Path(model_path)
        if not model_path.exists():
            raise FileNotFoundError('缺少 models/best.onnx，请解压完整程序文件夹，不要单独移动 EXE')
        options=ort.SessionOptions()
        options.intra_op_num_threads=max(1,min(4,os.cpu_count() or 1))
        options.inter_op_num_threads=1
        self.session=ort.InferenceSession(str(model_path),sess_options=options,providers=['CPUExecutionProvider'])
        self.input_name=self.session.get_inputs()[0].name
        shape=self.session.get_inputs()[0].shape
        self.height,self.width=int(shape[2]),int(shape[3])

    def predict(self, img, conf=0.5, iou=0.7, method=METHODS[0]):
        if not 0.01 <= conf <= 0.99 or not 0.1 <= iou <= 0.95:
            raise ValueError('阈值超出允许范围')
        start=time.perf_counter()
        image=transform(img,method)
        h,w=image.shape[:2]
        ratio=min(self.width/w,self.height/h)
        nw,nh=round(w*ratio),round(h*ratio)
        dw,dh=(self.width-nw)/2,(self.height-nh)/2
        left,top=round(dw-0.1),round(dh-0.1)
        resized=cv2.resize(image,(nw,nh),interpolation=cv2.INTER_LINEAR)
        padded=cv2.copyMakeBorder(resized,top,round(dh+0.1),left,round(dw+0.1),cv2.BORDER_CONSTANT,value=(114,114,114))
        blob=np.ascontiguousarray(padded[:,:,::-1].transpose(2,0,1)[None],dtype=np.float32)/255.0
        raw=self.session.run(None,{self.input_name:blob})[0]
        predictions=raw[0].T
        if predictions.shape[1] != 5:
            raise RuntimeError('本程序要求单类别 YOLOv8 检测模型，当前模型输出不匹配')
        predictions=predictions[predictions[:,4]>conf]
        scores=predictions[:,4]
        boxes=predictions[:,:4].copy()
        boxes[:,:2]-=boxes[:,2:]/2
        boxes[:,2:]+=boxes[:,:2]
        chosen=nms(boxes,scores,iou)
        boxes=boxes[chosen];scores=scores[chosen]
        boxes[:,[0,2]]=(boxes[:,[0,2]]-left)/ratio
        boxes[:,[1,3]]=(boxes[:,[1,3]]-top)/ratio
        boxes[:,[0,2]]=np.clip(boxes[:,[0,2]],0,w)
        boxes[:,[1,3]]=np.clip(boxes[:,[1,3]],0,h)
        order=np.lexsort((boxes[:,0],boxes[:,1])) if len(boxes) else []
        return {'boxes':boxes[order].tolist(),'scores':scores[order].tolist(),'count':len(boxes),
                'elapsed_ms':round((time.perf_counter()-start)*1000,1),'confidence':conf,'iou':iou,'method':method}

def annotate(img, result, numbers=True):
    out=img.copy(); scale=max(out.shape[:2])/1400
    width=max(2,round(scale*2));font=max(.45,scale*.48)
    for i,(box,score) in enumerate(zip(result['boxes'],result['scores']),1):
        x1,y1,x2,y2=map(int,box)
        cv2.rectangle(out,(x1,y1),(x2,y2),(50,210,70),width)
        if numbers:
            label=str(i);(tw,th),_=cv2.getTextSize(label,cv2.FONT_HERSHEY_SIMPLEX,font,width)
            yy=max(th+6,y1)
            cv2.rectangle(out,(x1,yy-th-6),(x1+tw+6,yy+2),(30,60,30),-1)
            cv2.putText(out,label,(x1+3,yy-2),cv2.FONT_HERSHEY_SIMPLEX,font,(255,255,255),width,cv2.LINE_AA)
    return out

def export_results(folder, results, numbers=True, export_stages=False):
    folder=Path(folder);folder.mkdir(parents=True,exist_ok=True)
    rows=[]
    for index,result in enumerate(results,1):
        path=Path(result['path']);img=read_image(path)
        stem=f'{index:03d}_{path.stem}'
        write_image(folder/(stem+'_检测.png'),annotate(img,result,numbers))
        (folder/(stem+'_检测.json')).write_text(json.dumps({**result,'path':path.name},ensure_ascii=False,indent=2),encoding='utf-8')
        if export_stages:
            for k,(title,stage) in enumerate(processing_stages(img),1):
                write_image(folder/(stem+f'_步骤{k}.png'),stage)
        reference=result.get('reference_count')
        rows.append({'图片':path.name,'预测数量':result['count'],'参考标注':reference if reference is not None else '',
            '差值':result['count']-reference if reference is not None else '',
            '置信度':result['confidence'],'NMS阈值':result['iou'],'方法':result['method'],'处理耗时毫秒':result['elapsed_ms']})
    with (folder/'计数汇总.csv').open('w',newline='',encoding='utf-8-sig') as f:
        fields=['图片','预测数量','参考标注','差值','置信度','NMS阈值','方法','处理耗时毫秒']
        writer=csv.DictWriter(f,fieldnames=fields);writer.writeheader();writer.writerows(rows)
    return folder
