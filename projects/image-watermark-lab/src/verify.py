from pathlib import Path
import json,io
from PIL import Image
from core import *
def run_tests(output):
    output=Path(output);output.mkdir(parents=True,exist_ok=True);checks=[]
    def check(name,condition):
        if not condition:raise AssertionError(name)
        checks.append({'name':name,'pass':True});print('PASS',name,flush=True)
    text='Watermark 2026';bits=packet(text)
    check('UTF8 packet roundtrip',decode(bits)['text']==text)
    bad=bits.copy();bad[80]^=1;check('CRC rejects corrupted payload',not decode(bad)['valid'])
    for value in ['', '中'*17]:
        try:packet(value);ok=False
        except ValueError:ok=True
        check('reject invalid text '+str(len(value)),ok)
    import sys
    assets=Path(getattr(sys,'_MEIPASS',Path(__file__).parent))
    arr=image_read((assets/'samples/campus.png').read_bytes());out=embed(arr,text)
    path=output/'中文路径 水印.png';save_img(path,out);reload=image_read(path.read_bytes())
    check('Chinese path PNG roundtrip',np.array_equal(out,reload))
    check('Blind extraction fresh engine',decode(extract_bits(reload))['text']==text)
    check('Wrong password rejected',not decode(extract_bits(reload,2027))['valid'])
    check('Unmarked input rejected',not decode(extract_bits(arr))['valid'])
    check('Wrong strength rejected',not decode(extract_bits(reload,strength='增强'))['valid'])
    check('JPEG90 demo roundtrip',decode(extract_bits(attack(out,'JPEG质量90')))['text']==text)
    check('LSB original roundtrip',decode(extract_bits(embed(arr,text,method='LSB'),method='LSB'))['text']==text)
    for label,raw in [('corrupt',b'not an image'),('small',None)]:
        if raw is None:
            f=io.BytesIO();Image.new('RGB',(32,32)).save(f,format='PNG');raw=f.getvalue()
        try:image_read(raw);ok=False
        except ValueError:ok=True
        check('Reject '+label,ok)
    f=io.BytesIO();Image.new('L',(512,512),128).save(f,format='PNG');a=image_read(f.getvalue());check('Grayscale normalized',a.shape==(512,512,3))
    f=io.BytesIO();Image.new('RGBA',(512,512),(0,0,0,0)).save(f,format='PNG');a=image_read(f.getvalue());check('Transparency composited white',bool(np.all(a==255)))
    check('Blank image safe result type',isinstance(decode(extract_bits(a))['valid'],bool))
    (output/'checks.json').write_text(json.dumps(checks,indent=2),encoding='utf-8');return checks
if __name__=='__main__':
    import sys;run_tests(sys.argv[1] if len(sys.argv)>1 else 'verification_output')
