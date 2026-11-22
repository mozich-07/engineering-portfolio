"""Offline shelf detection. Coordinates in source-image pixels."""
from pathlib import Path
import time
import cv2
import numpy as np
import onnxruntime as ort

def nms(boxes, scores, iou=0.7):
    if len(boxes)==0:return np.array([],dtype=int)
    b=np.asarray(boxes,np.float32)
    xywh=np.column_stack([b[:,:2],b[:,2:]-b[:,:2]])
    keep=cv2.dnn.NMSBoxes(xywh.tolist(),np.asarray(scores).tolist(),0.0001,float(iou),top_k=2000)
    return np.asarray(keep,dtype=int).reshape(-1)

class ShelfDetector:
    def __init__(self, model_dir):
        self.model_dir=Path(model_dir);self.sessions={}
    def session(self,model):
        if model not in ('n','s'):raise ValueError('未知模型')
        if model not in self.sessions:
            opts=ort.SessionOptions();opts.intra_op_num_threads=4;opts.inter_op_num_threads=1
            self.sessions[model]=ort.InferenceSession(str(self.model_dir/f'shelf_{model}.onnx'),
                sess_options=opts,providers=['CPUExecutionProvider'])
        return self.sessions[model]
    def raw(self,image,model='s'):
        h,w=image.shape[:2];ratio=min(640/w,640/h)
        nw,nh=round(w*ratio),round(h*ratio)
        left,top=(640-nw)//2,(640-nh)//2
        resized=cv2.resize(image,(nw,nh))
        frame=np.full((640,640,3),114,np.uint8)
        frame[top:top+nh,left:left+nw]=resized
        tensor=np.ascontiguousarray(frame[:,:,::-1].transpose(2,0,1)[None],dtype=np.float32)/255
        session=self.session(model);out=session.run(None,{session.get_inputs()[0].name:tensor})[0]
        # YOLO11 export: [1, 5, 8400], cx cy w h and one product score.
        p=out[0].T
        if p.shape[1]!=5:raise ValueError(f'不支持的模型输出 {out.shape}')
        p=p[p[:,4]>=0.01]
        boxes=np.column_stack([p[:,:2]-p[:,2:4]/2,p[:,:2]+p[:,2:4]/2])
        boxes[:,[0,2]]=(boxes[:,[0,2]]-left)/ratio
        boxes[:,[1,3]]=(boxes[:,[1,3]]-top)/ratio
        boxes[:,[0,2]]=boxes[:,[0,2]].clip(0,w)
        boxes[:,[1,3]]=boxes[:,[1,3]].clip(0,h)
        keep=(boxes[:,2]-boxes[:,0]>1)&(boxes[:,3]-boxes[:,1]>1)
        return boxes[keep],p[keep,4]
    def proposals(self,image,model='s',mode='full'):
        if mode=='full':return self.raw(image,model)
        if mode!='tiles':raise ValueError('未知检测模式')
        h,w=image.shape[:2];all_b=[];all_s=[]
        # 20% overlap protects objects near the middle boundary.
        # Each center belongs to exactly one half-open quadrant.
        for iy in range(2):
            for ix in range(2):
                x0=0 if ix==0 else int(w*.4);x1=int(w*.6) if ix==0 else w
                y0=0 if iy==0 else int(h*.4);y1=int(h*.6) if iy==0 else h
                b,s=self.raw(image[y0:y1,x0:x1],model)
                b+=np.array([x0,y0,x0,y0],np.float32)
                centers=(b[:,:2]+b[:,2:])/2
                keep=(centers[:,0]>=w*ix/2)&(centers[:,0]<w*(ix+1)/2)&(
                    centers[:,1]>=h*iy/2)&(centers[:,1]<h*(iy+1)/2)
                all_b.append(b[keep]);all_s.append(s[keep])
        return np.concatenate(all_b),np.concatenate(all_s)
    def predict(self,image,model='s',mode='full',conf=.25,iou=.7):
        started=time.perf_counter()
        boxes,scores=self.proposals(image,model,mode)
        keep=scores>=float(conf);boxes,scores=boxes[keep],scores[keep]
        idx=nms(boxes,scores,iou)
        return {'boxes':[{'id':i+1,'box':[round(float(v),2) for v in boxes[j]],
                         'score':round(float(scores[j]),5),'manual':False} for i,j in enumerate(idx)],
                'seconds':round(time.perf_counter()-started,4),'model':model,'mode':mode,
                'conf':float(conf),'iou':float(iou),'width':image.shape[1],'height':image.shape[0]}
