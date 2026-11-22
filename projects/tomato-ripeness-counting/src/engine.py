"""YOLOv8 three-stage tomato detector; CPU ONNX inference in original pixels."""
from pathlib import Path
import time
import cv2
import numpy as np
import onnxruntime as ort

STAGES = ["未成熟", "半成熟", "成熟"]

class TomatoDetector:
    def __init__(self, model_dir):
        self.model_dir=Path(model_dir)
        self.sessions={}

    def session(self, model):
        if model not in ("finetune","baseline"): raise ValueError("未知模型")
        if model not in self.sessions:
            opts=ort.SessionOptions()
            opts.intra_op_num_threads=4
            opts.inter_op_num_threads=1
            self.sessions[model]=ort.InferenceSession(str(self.model_dir/f"{model}.onnx"),
                sess_options=opts,providers=["CPUExecutionProvider"])
        return self.sessions[model]

    def predict(self,image,model="finetune",conf=.25,iou=.6):
        started=time.perf_counter()
        h,w=image.shape[:2]
        ratio=min(640/w,640/h)
        nw,nh=round(w*ratio),round(h*ratio)
        left,top=(640-nw)//2,(640-nh)//2
        frame=np.full((640,640,3),114,np.uint8)
        frame[top:top+nh,left:left+nw]=cv2.resize(image,(nw,nh))
        tensor=np.ascontiguousarray(frame[:,:,::-1].transpose(2,0,1)[None],dtype=np.float32)/255
        session=self.session(model)
        out=session.run(None,{session.get_inputs()[0].name:tensor})[0]
        p=out[0].T
        if p.shape[1]!=7:raise ValueError(f"模型输出格式不符：{out.shape}")
        cls=p[:,4:].argmax(1)
        scores=p[:,4:].max(1)
        active=scores>=conf
        p,cls,scores=p[active],cls[active],scores[active]
        boxes=np.column_stack((p[:,:2]-p[:,2:4]/2,p[:,:2]+p[:,2:4]/2))
        # Class-agnostic NMS: a tomato is counted once even when stages compete.
        xywh=np.column_stack((boxes[:,:2],boxes[:,2:]-boxes[:,:2]))
        idx=np.asarray(cv2.dnn.NMSBoxes(xywh.tolist(),scores.tolist(),
            float(conf),float(iou),top_k=3000),dtype=int).reshape(-1)
        boxes[:,[0,2]]=(boxes[:,[0,2]]-left)/ratio
        boxes[:,[1,3]]=(boxes[:,[1,3]]-top)/ratio
        boxes[:,[0,2]]=boxes[:,[0,2]].clip(0,w)
        boxes[:,[1,3]]=boxes[:,[1,3]].clip(0,h)
        items=[]
        for j in idx:
            if boxes[j,2]-boxes[j,0]<=1 or boxes[j,3]-boxes[j,1]<=1:continue
            items.append({"id":len(items)+1,"box":[round(float(v),3) for v in boxes[j]],
                          "stage":int(cls[j]),"score":round(float(scores[j]),6),"manual":False})
        return {"boxes":items,"counts":[sum(b["stage"]==c for b in items) for c in range(3)],
                "seconds":round(time.perf_counter()-started,4),"model":model,"conf":conf,"iou":iou,
                "width":w,"height":h}
