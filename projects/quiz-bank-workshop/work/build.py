import pathlib,json,re
root=pathlib.Path(__file__).resolve().parent
out=root.parent/'outputs'
out.mkdir(exist_ok=True)
def safe_json(data):
 return json.dumps(data,ensure_ascii=False).replace('<','\\u003c').replace('\u2028','\\u2028').replace('\u2029','\\u2029')
banks=json.loads((root/'banks.json').read_text(encoding='utf-8'))
body=(root/'body.html').read_text(encoding='utf-8')
html='<!DOCTYPE html>\n<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>题库工坊 · Word 导入与错题复习</title><style id="app-style">'+(root/'style.css').read_text(encoding='utf-8')+'</style></head><body>'+body
html+='<script id="seed" type="application/json">'+safe_json(banks)+'</script>'
html+='<script id="boot">window.SEED_BANKS=JSON.parse(document.getElementById("seed").textContent);window.APP_SCOPE="main";window.APP_BODY='+safe_json(body)+';</script>'
for id,file in [('vendor','mammoth.browser.min.js'),('engine','engine.js'),('application','app.js')]:
 code=(root/file).read_text(encoding='utf-8').replace('</script','<\\/script')
 if id=='vendor': code='/* Mammoth.js 1.11.0 — https://github.com/mwilliamson/mammoth.js\n'+(root/'MAMMOTH-LICENSE.txt').read_text(encoding='utf-8')+'\n*/\n'+code
 html+='<script id="'+id+'">'+code+'</script>'
html+='</body></html>'
(out/'题库工坊.html').write_text(html,encoding='utf-8')
print('Built:',len(html.encode('utf-8')),'bytes')
