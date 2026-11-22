"""离线推理：RGB letterbox -> YOLO26 ONNX -> 人员与装备空间关联。"""
from pathlib import Path
import io,base64,time
import numpy as np
import cv2
import onnxruntime as ort
from PIL import Image,ImageDraw,ImageFont,ImageOps

NAMES=['安全帽','反光衣','人员','疑似未戴安全帽']
COLORS=['#15803d','#0369a1','#475569','#dc2626']
FONT_PATH='C:/Windows/Fonts/msyh.ttc'
def font(size):
 try:return ImageFont.truetype(FONT_PATH,size)
 except OSError:return ImageFont.load_default(size=size)
def read_image(data):
 if len(data)>25*1024*1024:raise ValueError('图片超过 25 MB，请缩小后导入。')
 with Image.open(io.BytesIO(data)) as src:
  if src.width*src.height>40_000_000:raise ValueError('图片超过 4000 万像素，请缩小后导入。')
  im=ImageOps.exif_transpose(src).convert('RGB')
 if min(im.size)<16:raise ValueError('图片尺寸过小。')
 return im
def prepare(im,size=640):
 a=np.asarray(im); h,w=a.shape[:2]; r=min(size/h,size/w)
 nw,nh=round(w*r),round(h*r)
 a=cv2.resize(a,(nw,nh),interpolation=cv2.INTER_LINEAR)
 dw,dh=(size-nw)/2,(size-nh)/2
 left,top=round(dw-.1),round(dh-.1)
 a=cv2.copyMakeBorder(a,top,round(dh+.1),left,round(dw+.1),cv2.BORDER_CONSTANT,value=(114,114,114))
 return np.ascontiguousarray(a.transpose(2,0,1)[None],dtype=np.float32)/255.,r,(left,top)
def associate(dets):
 persons=[dict(box=d['box'],score=d['score'],helmet=None,vest=None,no_helmet=None) for d in dets if d['class_id']==2]
 for d in [d for d in dets if d['class_id']!=2]:
  x1,y1,x2,y2=d['box'];cx,cy=(x1+x2)/2,(y1+y2)/2;area=max(1,(x2-x1)*(y2-y1));opts=[]
  for i,p in enumerate(persons):
   a,b,c,e=p['box'];ph=max(1,e-b);pw=max(1,c-a)
   inter=max(0,min(x2,c)-max(x1,a))*max(0,min(y2,e)-max(y1,b))/area
   ry=(cy-b)/ph
   allowed=(-.05<=ry<=.5) if d['class_id'] in (0,3) else (.1<=ry<=.85)
   if inter>=.6 and a<=cx<=c and allowed:
    target=.15 if d['class_id'] in (0,3) else .45
    cost=abs((cx-a)/pw-.5)+abs(ry-target)
    opts.append((cost,i))
  if opts:
   p=persons[min(opts)[1]];key={0:'helmet',1:'vest',3:'no_helmet'}[d['class_id']]
   if p[key] is None or d['score']>p[key]:p[key]=d['score']
 for i,p in enumerate(persons):
  p['id']=i+1
  if p['helmet'] and p['no_helmet']:p.update(status='证据冲突，需复核',level='review')
  elif p['no_helmet']:p.update(status='疑似未戴安全帽',level='risk')
  elif p['helmet'] and p['vest']:p.update(status='安全帽与反光衣均检出',level='detected')
  else:p.update(status='装备检出不完整，需复核',level='review')
  p['helmet_text']='冲突待复核' if p['helmet'] and p['no_helmet'] else ('已检出' if p['helmet'] else ('疑似未戴' if p['no_helmet'] else '未检出，需复核'))
  p['vest_text']='已检出' if p['vest'] else '未检出，需复核'
 return persons
class Engine:
 def __init__(self,model):
  opts=ort.SessionOptions();opts.intra_op_num_threads=4
  self.session=ort.InferenceSession(str(model),sess_options=opts,providers=['CPUExecutionProvider'])
  self.input=self.session.get_inputs()[0].name
 def predict(self,im,conf=.35):
  tensor,r,(left,top)=prepare(im); t=time.perf_counter();out=self.session.run(None,{self.input:tensor})[0][0]
  elapsed=(time.perf_counter()-t)*1000
  if out.shape[-1]!=6:raise RuntimeError('模型输出格式与 NMS-free 部署约定不符。')
  result=[]
  for row in out:
   x1,y1,x2,y2,score,cls=map(float,row)
   if score<conf or int(cls) not in range(4):continue
   box=[float(np.clip((x1-left)/r,0,im.width)),float(np.clip((y1-top)/r,0,im.height)),float(np.clip((x2-left)/r,0,im.width)),float(np.clip((y2-top)/r,0,im.height))]
   if box[2]<=box[0] or box[3]<=box[1]:continue
   result.append({'class_id':int(cls),'name':NAMES[int(cls)],'score':round(score,6),'box':box})
  return {'detections':result,'persons':associate(result),'inference_ms':round(elapsed,1),'width':im.width,'height':im.height,'confidence':conf}
def annotate(im,result):
 out=im.copy();d=ImageDraw.Draw(out);size=max(14,round(min(out.size)/35));ft=font(size);width=max(2,size//6)
 for obj in result['detections']:
  if obj['class_id']==2:continue
  box=obj['box'];color=COLORS[obj['class_id']];d.rectangle(box,outline=color,width=width)
  text=f'{obj["name"]} {obj["score"]:.0%}';bb=d.textbbox((0,0),text,font=ft);tw=bb[2];th=bb[3]+4
  x=min(max(0,box[0]),max(0,out.width-tw-8));y=max(0,box[1]-th)
  d.rectangle((x,y,x+tw+8,y+th),fill=color);d.text((x+4,y),text,font=ft,fill='white')
 for p in result['persons']:
  color={'risk':'#dc2626','detected':'#15803d','review':'#b45309'}[p['level']];d.rectangle(p['box'],outline=color,width=width)
  label=f'人员 {p["id"]}';x=p['box'][0];y=max(0,p['box'][3]-size*1.6)
  d.rectangle((x,y,x+size*4.5,y+size*1.6),fill=color);d.text((x+3,y),label,font=ft,fill='white')
 return out
def image_uri(im):
 f=io.BytesIO();im.save(f,format='JPEG',quality=93);return 'data:image/jpeg;base64,'+base64.b64encode(f.getvalue()).decode()
