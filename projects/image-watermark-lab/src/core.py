"""Image watermarking integration of blind-watermark 0.4.4 (MIT); upstream algorithm unchanged."""
from pathlib import Path
import io, json, struct, zlib, time
import numpy as np
import cv2
from PIL import Image, ImageOps
from blind_watermark import WaterMark
from blind_watermark.version import bw_notes
from blind_watermark.bwm_core import one_dim_kmeans
bw_notes.close()

MAX_TEXT = 48
PACKET_BYTES = 56
BITS = PACKET_BYTES * 8
STRENGTHS = {'轻度': (24, 12), '标准': (36, 20), '增强': (60, 32)}
ATTACKS = ['原样PNG', 'JPEG质量90', 'JPEG质量70', 'JPEG质量40', '缩小一半再恢复', '亮度降低10%', '高斯噪声σ3', '中心遮挡10%', '旋转2度', '中心裁剪10%再恢复']

def image_read(data):
    try:
        with Image.open(io.BytesIO(data)) as src:
            if src.width * src.height > 20_000_000:
                raise ValueError('图片超过2000万像素，请先缩小。')
            im = ImageOps.exif_transpose(src).convert('RGBA')
            bg = Image.new('RGBA', im.size, 'white'); bg.alpha_composite(im)
            arr = np.asarray(bg.convert('RGB'))[:, :, ::-1].copy()
    except ValueError:
        raise
    except Exception as exc:
        raise ValueError('无法读取图片，请使用正常的PNG或JPEG图片。') from exc
    if min(arr.shape[:2]) < 256 or max(arr.shape[:2]) > 1600:
        raise ValueError('图片每边至少256像素、最长边不超过1600像素。请先调整尺寸；提取时不要随意缩放。')
    return arr

def save_img(path, arr):
    path = Path(path); path.parent.mkdir(parents=True, exist_ok=True)
    ok, buf = cv2.imencode(path.suffix, arr)
    if not ok: raise ValueError('图片编码失败')
    path.write_bytes(buf.tobytes())

def packet(text):
    raw = text.encode('utf-8')
    if not 1 <= len(raw) <= MAX_TEXT:
        raise ValueError('水印须为1至48个UTF-8字节，中文通常每字3字节。')
    head = b'WM1' + bytes([len(raw)]) + raw.ljust(MAX_TEXT, b'\0')
    return np.unpackbits(np.frombuffer(head + struct.pack('>I', zlib.crc32(head)), dtype=np.uint8))

def decode(bits):
    raw = np.packbits(np.asarray(bits) >= .5).tobytes()
    if len(raw) != PACKET_BYTES or raw[:3] != b'WM1' or not 1 <= raw[3] <= MAX_TEXT:
        return {'valid': False, 'text': '', 'message': '未通过校验：参数不符、无本系统水印或图像已受损。'}
    if zlib.crc32(raw[:-4]) != struct.unpack('>I', raw[-4:])[0]:
        return {'valid': False, 'text': '', 'message': '未通过CRC校验，提取位序列存在错误。'}
    try: text = raw[4:4+raw[3]].decode('utf-8')
    except UnicodeDecodeError: return {'valid': False, 'text': '', 'message': '文本编码校验失败。'}
    return {'valid': True, 'text': text, 'message': '校验通过，成功提取文本。'}

def engine(password, strength):
    password = int(password)
    if not 0 <= password <= 4294967295: raise ValueError('密码须为0至4294967295的整数。')
    if strength not in STRENGTHS: raise ValueError('未知嵌入强度')
    obj = WaterMark(password_img=password, password_wm=password, mode='common')
    obj.bwm_core.d1, obj.bwm_core.d2 = STRENGTHS[strength]
    return obj

def embed(arr, text, password=2026, strength='标准', method='DWT-DCT-SVD'):
    bits = packet(text)
    if method == 'LSB':
        out = arr.copy(); blue = out[:, :, 0].copy().ravel()
        blue[:BITS] = (blue[:BITS] & 254) | bits
        out[:, :, 0] = blue.reshape(arr.shape[:2]); return out
    if method != 'DWT-DCT-SVD': raise ValueError('未知方法')
    if ((arr.shape[0]+1)//8)*((arr.shape[1]+1)//8) <= BITS:
        raise ValueError('图像块数量不足，请使用更大的图片。')
    obj = engine(password, strength); obj.read_img(img=arr); obj.read_wm(bits, mode='bit')
    return np.rint(obj.embed()).clip(0,255).astype(np.uint8)

def extract_bits(arr, password=2026, strength='标准', method='DWT-DCT-SVD'):
    if method == 'LSB': return (arr[:, :, 0].ravel()[:BITS] & 1).astype(np.uint8)
    if method != 'DWT-DCT-SVD': raise ValueError('未知方法')
    obj=engine(password,strength); obj.wm_size=BITS
    # Upstream k-means has an empty cluster when all recovered scores are equal.
    # A constant score cannot represent our framed packet: reject safely before clustering.
    avg=obj.bwm_core.extract(img=arr,wm_shape=BITS)
    if not np.isfinite(avg).all() or np.ptp(avg)<1e-9:
        return np.zeros(BITS,dtype=np.uint8)
    recovered=one_dim_kmeans(avg)
    return np.asarray(obj.extract_decrypt(recovered),dtype=np.uint8)

def metrics(a,b):
    mse=float(np.mean((a.astype(float)-b.astype(float))**2))
    return {'mse':round(mse,6), 'psnr_db':round(10*np.log10(255**2/mse),4) if mse else None}

def attack(arr,name):
    h,w=arr.shape[:2]
    if name == '原样PNG': return arr.copy()
    if name.startswith('JPEG质量'):
        quality=int(name.replace('JPEG质量',''))
        _, buf=cv2.imencode('.jpg',arr,[cv2.IMWRITE_JPEG_QUALITY,quality])
        return cv2.imdecode(buf,cv2.IMREAD_COLOR)
    if name == '缩小一半再恢复': return cv2.resize(cv2.resize(arr,(w//2,h//2),interpolation=cv2.INTER_AREA),(w,h),interpolation=cv2.INTER_CUBIC)
    if name == '亮度降低10%': return np.rint(arr.astype(float)*.9).astype(np.uint8)
    if name == '高斯噪声σ3': return np.rint(arr.astype(float)+np.random.default_rng(2026).normal(0,3,arr.shape)).clip(0,255).astype(np.uint8)
    if name == '中心遮挡10%':
        out=arr.copy(); bw,bh=int(w*np.sqrt(.1)),int(h*np.sqrt(.1)); x,y=(w-bw)//2,(h-bh)//2
        out[y:y+bh,x:x+bw]=127; return out
    if name == '旋转2度': return cv2.warpAffine(arr,cv2.getRotationMatrix2D((w/2,h/2),2,1),(w,h),borderMode=cv2.BORDER_REFLECT)
    if name == '中心裁剪10%再恢复':
        x,y=int(w*.05),int(h*.05); return cv2.resize(arr[y:h-y,x:w-x],(w,h),interpolation=cv2.INTER_CUBIC)
    raise ValueError('未知处理方式')

def experiment(arr,text,password,strength,dest,progress=lambda s:None,cancel=lambda:False):
    dest=Path(dest);dest.mkdir(parents=True,exist_ok=True); rows=[]; ref=packet(text)
    save_img(dest/'original.png',arr)
    for method in ['DWT-DCT-SVD','LSB']:
        progress('正在嵌入 '+method); out=embed(arr,text,password,strength,method)
        prefix='dwt' if method=='DWT-DCT-SVD' else 'lsb'
        save_img(dest/f'{prefix}_embedded.png',out)
        for idx,name in enumerate(ATTACKS):
            if cancel(): raise InterruptedError('实验已停止，未导出不完整结果。')
            progress(f'{method}：{name}（{idx+1}/{len(ATTACKS)}）')
            t=time.perf_counter(); changed=attack(out,name); got=extract_bits(changed,password,strength,method)
            result=decode(got); filename=f'{prefix}_{idx:02}.png'; save_img(dest/filename,changed)
            rows.append({'method':method,'attack':name,'valid':result['valid'],'text':result['text'], 'ber':float(np.mean(got!=ref)),**metrics(arr,changed),'seconds':round(time.perf_counter()-t,3),'image':filename})
    return rows
