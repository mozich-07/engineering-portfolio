'use strict';
const C=BeadCore,$=id=>document.getElementById(id),A=BEAD_ASSETS;
let source=null,result=null,view='beads',editing=false,history=[],loadToken=0,custom=null;
const paletteNames={starter:'基础 36 色（演示色卡）',perler:'Perler 品牌参考色卡',custom:'自定义色卡'};
function status(text,error=false){$('status').textContent=text;$('status').classList.toggle('error',error);}
function invalidate(message='设置已更改，请重新生成图纸。'){
 result=null;history=[];editing=false;$('resultView').classList.remove('editing');$('enableEdit').textContent='开启点选编辑';
 $('resultView').textContent=message;$('materialBody').replaceChildren();$('materialTotal').textContent='';$('resultCaption').textContent=message;
 for(const id of ['total','used','dimensions','boards'])$(id).textContent='—';
 document.querySelectorAll('[data-export]').forEach(e=>e.disabled=true);$('undo').disabled=true;
 $('metric').textContent='色差评价基于自动配色结果。';status(message);
}
async function loadPhoto(src,name){
 const token=++loadToken;invalidate('正在读取照片…');source=null;
 try{
  const img=new Image();await new Promise((ok,no)=>{img.onload=ok;img.onerror=()=>no(Error('无法读取图片，请选择有效的 PNG、JPEG 或 WebP'));img.src=src;});
  if(token!==loadToken)return;
  if(img.width*img.height>40000000)throw Error('照片超过 4000 万像素，请缩小后导入');
  const scale=Math.min(1,1024/Math.max(img.width,img.height)),canvas=document.createElement('canvas');
  canvas.width=Math.max(1,Math.round(img.width*scale));canvas.height=Math.max(1,Math.round(img.height*scale));
  const ctx=canvas.getContext('2d',{willReadFrequently:true});ctx.drawImage(img,0,0,canvas.width,canvas.height);
  source={name,data:ctx.getImageData(0,0,canvas.width,canvas.height),originalWidth:img.width,originalHeight:img.height};
  $('original').src=src;$('photoTitle').textContent=name;
  status('照片已读取，可调整设置后生成。');
 }catch(e){if(token===loadToken){$('original').removeAttribute('src');status(e.message,true);}}
}
function options(){return {colors:+$('colors').value,method:$('method').value,cleanup:$('cleanup').checked,size:+$('size').value,fit:$('fit').value,contrast:+$('contrast').value,transparent:$('transparent').checked};}
function generate(){
 if(!source){status('请先导入一张照片。',true);return;}
 const opt=options(),p=$('palette').value;
 try{
  status('正在采样和配色…');
  const start=performance.now(),d=source.data,g=C.gridSize(d.width,d.height,opt.size,opt.fit);
  const pixels=C.sample(d.data,d.width,d.height,g.cols,g.rows,opt.fit,opt.transparent,opt.contrast);
  result=C.quantize(pixels,g.cols,g.rows,p==='custom'?custom:A.palettes[p],opt);
  result.name=source.name;result.paletteName=paletteNames[p];result.paletteKey=p;result.sourceSize=[source.originalWidth,source.originalHeight];
  result.elapsedMs=performance.now()-start;history=[];editing=false;
  fillEditor();render();status(`已生成 ${result.cols} × ${result.rows} 图纸，用时 ${Math.round(result.elapsedMs)} ms。`);
 }catch(e){invalidate();status(e.message,true);}
}
function supply(){const spare=Number($('spare').value),bag=Number($('bag').value);if($('spare').value===''||$('bag').value==='')throw Error('请填写余量和每袋颗数');return {spare,bag};}
function render(){
 if(!result)return;
 const r=result;
 $('resultView').innerHTML=C.svg(r,{cell:28,beads:view==='beads',labels:view==='pattern'});
 $('resultView').classList.toggle('editing',editing);$('viewCaption').textContent=view==='beads'?'拼豆效果预览':'带色号与全图坐标的图纸';
 $('enableEdit').textContent=editing?'关闭点选编辑':'开启点选编辑';
 document.querySelectorAll('[data-view]').forEach(b=>b.classList.toggle('active',b.dataset.view===view));
 $('resultCaption').textContent=`${r.cols} 列 × ${r.rows} 行 · ${r.paletteName||'自定义色卡'}${r.edits?' · 已手工编辑':''}`;
 const actual=C.materials(r,0,100),total=actual.reduce((s,p)=>s+p.count,0);
 $('total').textContent=total.toLocaleString();$('used').textContent=actual.length;
 $('dimensions').textContent=`${(r.cols*.5).toFixed(1)} × ${(r.rows*.5).toFixed(1)}`;
 $('boards').textContent=Math.ceil(r.cols/29)*Math.ceil(r.rows/29);
 $('metric').textContent=r.edits?'已手工编辑：自动配色误差不再适用。用量按当前图纸重新统计。':`自动配色平均 ΔE76：${Number(r.metrics.meanDeltaE||0).toFixed(2)}；RGB RMSE：${Number(r.metrics.rmse||0).toFixed(2)}。以采样图为参考，非实物色差测量。`;
 document.querySelectorAll('[data-export]').forEach(e=>e.disabled=false);$('undo').disabled=!history.length;
 renderMaterials();
}
function renderMaterials(){
 if(!result)return;
 try{
  const {spare,bag}=supply(),ms=C.materials(result,spare,bag);$('materialBody').replaceChildren();
  for(const m of ms){
   const tr=document.createElement('tr'),name=document.createElement('td'),swatch=document.createElement('span');
   swatch.className='swatch';swatch.style.backgroundColor=m.hex;name.append(swatch,document.createTextNode(m.code+' '+m.name));
   const hex=document.createElement('small');hex.textContent=' '+m.hex;name.append(hex);tr.append(name);
   for(const v of [m.source_code||'—',m.count,m.prepare,m.bags]){const td=document.createElement('td');td.textContent=v;tr.append(td);}
   $('materialBody').append(tr);
  }
  $('materialTotal').textContent=`合计实际 ${ms.reduce((s,m)=>s+m.count,0)} 颗；建议备料 ${ms.reduce((s,m)=>s+m.prepare,0)} 颗；${ms.reduce((s,m)=>s+m.bags,0)} 袋。`;
 }catch(e){$('materialBody').replaceChildren();$('materialTotal').textContent=e.message;status(e.message,true);}
}
function fillEditor(){
 $('editColor').replaceChildren();
 const empty=document.createElement('option');empty.value=-1;empty.textContent='留空 / 擦除';$('editColor').append(empty);
 result.palette.forEach((p,i)=>{const o=document.createElement('option');o.value=i;o.textContent=p.code+' '+p.name;$('editColor').append(o);});
 $('editColor').value=C.materials(result)[0]?.index??-1;
}
function editCell(x,y){
 if(!result)return;
 if(!Number.isInteger(x)||!Number.isInteger(y)||x<0||y<0||x>=result.cols||y>=result.rows){status('坐标超出图纸范围。',true);return;}
 const i=y*result.cols+x,value=+$('editColor').value;if(result.matrix[i]===value)return;
 history.push({i,old:result.matrix[i],edits:result.edits});result.matrix[i]=value;result.edits++;render();status(`已修改第 ${y+1} 行、第 ${x+1} 列，用量已更新。`);
}
function download(content,name,type){
 const url=URL.createObjectURL(new Blob([content],{type})),a=document.createElement('a');a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),30000);
}
const fileName=()=>String(result?.name||'拼豆').replace(/[<>:"/\\|?*\x00-\x1f]/g,'_').slice(0,60);
function guard(fn){return async()=>{if(!result){status('请先生成图纸。',true);return;}try{await fn();}catch(e){status(e.message,true);}};}
$('generate').onclick=generate;
$('demo').onclick=async()=>{ $('sampleGroup').value='推荐演示';filterSamples();$('size').value=48;$('colors').value=16;$('palette').value='starter';$('fit').value='aspect';$('method').value='lab';$('cleanup').checked=false;$('contrast').value='1';updateLabels();await selectSample(A.samples[0]);generate();};
async function selectSample(s){document.querySelectorAll('.sample').forEach(b=>b.classList.toggle('selected',b.dataset.id===s.id));await loadPhoto(s.src,s.name);}
for(const s of A.samples){
 const b=document.createElement('button');b.className='sample';b.dataset.id=s.id;b.title='选用'+s.name+'照片';const im=document.createElement('img');im.src=s.src;im.alt='';b.append(im,document.createTextNode(s.name));b.dataset.group=s.group;b.onclick=async()=>{await selectSample(s);generate();};$('samples').append(b);
}
function filterSamples(){document.querySelectorAll('.sample').forEach(b=>b.hidden=$('sampleGroup').value!=='all'&&b.dataset.group!==$('sampleGroup').value);$('samples').scrollTop=0;}
$('sampleGroup').onchange=filterSamples;filterSamples();
$('photo').onchange=async e=>{
 const f=e.target.files[0];if(!f)return;
 if(f.size>20*1024*1024){loadToken++;source=null;$('original').removeAttribute('src');invalidate('照片过大，请使用 20 MB 以内的照片。');return;}
 const url=URL.createObjectURL(f);await loadPhoto(url,f.name.replace(/\.[^.]+$/,''));URL.revokeObjectURL(url);
};
function updateLabels(){$('sizeValue').textContent=$('size').value+' 颗';$('colorsValue').textContent=$('colors').value+' 色';}
for(const id of ['size','colors','palette','fit','method','cleanup','transparent','contrast'])$(id).oninput=()=>{updateLabels();invalidate();};
for(const id of ['spare','bag'])$(id).oninput=renderMaterials;
document.querySelectorAll('[data-view]').forEach(b=>b.onclick=()=>{view=b.dataset.view;if(view==='beads')editing=false;render();});
$('enableEdit').onclick=()=>{if(!result){status('请先生成图纸。',true);return;}editing=!editing;view='pattern';render();};
$('applyCell').onclick=()=>editCell(+$('editCol').value-1,+$('editRow').value-1);
$('resultView').onclick=e=>{
 if(!editing||!result)return;const svg=$('resultView').querySelector('svg');if(!svg)return;
 const rect=svg.getBoundingClientRect(),scale=svg.viewBox.baseVal.width/rect.width;
 editCell(Math.floor(((e.clientX-rect.left)*scale-30)/28),Math.floor(((e.clientY-rect.top)*scale-30)/28));
};
$('undo').onclick=()=>{const last=history.pop();if(last&&result){result.matrix[last.i]=last.old;result.edits=last.edits;render();status('已撤销上一步。');}};
$('exportSVG').onclick=guard(()=>download(C.svg(result),fileName()+'_编号图纸.svg','image/svg+xml'));
$('exportCSV').onclick=guard(()=>{const s=supply();download(C.csv(result,s.spare,s.bag),fileName()+'_材料.csv','text/csv;charset=utf-8');});
$('exportMatrix').onclick=guard(()=>download(C.matrixCSV(result),fileName()+'_矩阵.csv','text/csv;charset=utf-8'));
$('saveProject').onclick=guard(()=>download(JSON.stringify(result,null,2),fileName()+'_项目.json','application/json'));
$('exportPNG').onclick=guard(async()=>{
 const im=new Image(),url=URL.createObjectURL(new Blob([C.svg(result,{beads:true,labels:false})],{type:'image/svg+xml'}));
 await new Promise((ok,no)=>{im.onload=ok;im.onerror=no;im.src=url;});
 const cv=document.createElement('canvas');cv.width=im.width;cv.height=im.height;cv.getContext('2d').drawImage(im,0,0);
 const blob=await new Promise(ok=>cv.toBlob(ok));download(blob,fileName()+'_预览.png','image/png');URL.revokeObjectURL(url);
});
$('print').onclick=guard(()=>{
 const s=supply(),html=C.printHTML(result,s.spare,s.bag,$('mono').checked),win=window.open('','_blank');
 if(win){win.document.open();win.document.write(html);win.document.close();}else{download(html,fileName()+'_打印.html','text/html;charset=utf-8');status('打印窗口被拦截，已保存可打印的 HTML 文件。');}
});
$('paletteTemplate').onclick=()=>download(JSON.stringify(A.palettes.starter,null,2),'自定义色卡模板.json','application/json');
$('paletteFile').onchange=async e=>{
 const f=e.target.files[0];if(!f)return;
 try{if(f.size>1000000)throw Error('色卡文件过大');custom=C.validatePalette(JSON.parse(await f.text()));
 if(!$('palette').querySelector('[value=custom]')){const o=document.createElement('option');o.value='custom';o.textContent='自定义色卡';$('palette').append(o);}
 $('palette').value='custom';invalidate('色卡已导入，请重新生成。');}catch(e){status(e.message,true);}
};
$('projectFile').onchange=async e=>{
 const f=e.target.files[0];if(!f)return;
 try{if(f.size>3000000)throw Error('项目文件过大');const r=C.validateProject(JSON.parse(await f.text()));loadToken++;source=null;result=r;history=[];editing=false;view='pattern';$('original').removeAttribute('src');$('photoTitle').textContent=r.name||'已保存的图纸';fillEditor();render();status('图纸已恢复，可继续编辑和导出。重新生成需要重新选择照片。');}catch(e){status(e.message,true);}
};
window.beadApp={getResult:()=>result,getSource:()=>source,generate,loadPhoto,selectSample,editCell};
invalidate('请选择照片并生成图纸。');selectSample(A.samples[0]).then(generate);
