/* This edition accepts a caller-supplied palette. */
(function(root){
'use strict';
const rgb=hex=>hex.slice(1).match(/../g).map(v=>parseInt(v,16));
function lab(c){
 const v=c.map(x=>{x/=255;return x<=.04045?x/12.92:((x+.055)/1.055)**2.4;});
 const t=[(.4124564*v[0]+.3575761*v[1]+.1804375*v[2])/.95047,.2126729*v[0]+.7151522*v[1]+.072175*v[2],(.0193339*v[0]+.119192*v[1]+.9503041*v[2])/1.08883].map(x=>x>.008856?Math.cbrt(x):7.787*x+16/116);
 return [116*t[1]-16,500*(t[0]-t[1]),200*(t[1]-t[2])];
}
const dist=(a,b)=>a.reduce((s,v,i)=>s+(v-b[i])**2,0);
function validatePalette(rows){
 if(!Array.isArray(rows)||!rows.length||rows.length>256)throw Error('色卡须包含 1 至 256 色');
 const seen=new Set();
 return rows.map(p=>{
  const code=String(p.code||'').trim(),name=String(p.name||code).trim(),hex=String(p.hex||'').trim();
  if(!/^[A-Za-z0-9_-]{1,8}$/.test(code)||seen.has(code))throw Error('色号须为不重复的 1 至 8 位字母、数字、下划线或短横线');
  if(!/^#[0-9a-f]{6}$/i.test(hex)||name.length>80)throw Error('颜色须为 #RRGGBB，名称不超过 80 字');
  seen.add(code);return {code,name,hex:hex.toUpperCase(),source_code:String(p.source_code||'').slice(0,80)};
 });
}
function gridSize(w,h,size,fit='aspect'){
 if(!Number.isFinite(w)||!Number.isFinite(h)||w<1||h<1||!Number.isInteger(size)||size<8||size>96)throw Error('长边应为 8 至 96 颗');
 return fit==='square'?{cols:size,rows:size}:{cols:Math.max(1,Math.round(size*w/Math.max(w,h))),rows:Math.max(1,Math.round(size*h/Math.max(w,h)))};
}
// Exact area weights on the normalized source raster.
function sample(data,w,h,cols,rows,fit='aspect',skip=true,contrast=1){
 let sx=0,sy=0,sw=w,sh=h;
 if(fit==='square'){sw=sh=Math.min(w,h);sx=(w-sw)/2;sy=(h-sh)/2;}
 const pixels=[];
 for(let y=0;y<rows;y++)for(let x=0;x<cols;x++){
  const x0=sx+x*sw/cols,x1=sx+(x+1)*sw/cols,y0=sy+y*sh/rows,y1=sy+(y+1)*sh/rows;
  let sum=[0,0,0],alpha=0,weight=0;
  for(let yy=Math.floor(y0);yy<Math.ceil(y1)&&yy<h;yy++)for(let xx=Math.floor(x0);xx<Math.ceil(x1)&&xx<w;xx++){
   const a=Math.max(0,Math.min(x1,xx+1)-Math.max(x0,xx))*Math.max(0,Math.min(y1,yy+1)-Math.max(y0,yy));
   const i=(yy*w+xx)*4,op=data[i+3]/255;
   weight+=a;alpha+=op*a;for(let k=0;k<3;k++)sum[k]+=data[i+k]*op*a;
  }
  if(skip&&alpha/weight<.5){pixels.push(null);continue;}
  pixels.push(sum.map(v=>Math.max(0,Math.min(255,((v+255*(weight-alpha))/weight-128)*contrast+128))));
 }
 return pixels;
}
function quantize(pixels,cols,rows,palette,options={}){
 palette=validatePalette(palette);
 const limit=Math.max(1,Math.min(palette.length,Math.round(options.colors||16)));
 const feature=options.method==='rgb'?x=>x:lab;
 const pf=palette.map(p=>feature(rgb(p.hex))),features=pixels.map(p=>p?feature(p):null);
 function nearest(f,allowed){let best=allowed[0],d=Infinity;for(const i of allowed){const v=dist(f,pf[i]);if(v<d){d=v;best=i;}}return best;}
 const all=palette.map((_,i)=>i),counts=new Array(palette.length).fill(0);
 for(const f of features)if(f)counts[nearest(f,all)]++;
 const allowed=all.sort((a,b)=>counts[b]-counts[a]||a-b).slice(0,limit);
 const matrix=features.map(f=>f?nearest(f,allowed):-1);
 if(options.cleanup){
  const old=matrix.slice();
  for(let y=1;y<rows-1;y++)for(let x=1;x<cols-1;x++){
   const i=y*cols+x;if(old[i]<0)continue;const n=[old[i-1],old[i+1],old[i-cols],old[i+cols]];
   for(const c of n)if(c>=0&&c!==old[i]&&n.filter(v=>v===c).length>=3){matrix[i]=c;break;}
  }
 }
 let de=0,se=0,n=0;
 matrix.forEach((v,i)=>{if(v<0)return;const c=rgb(palette[v].hex);de+=Math.sqrt(dist(lab(pixels[i]),lab(c)));se+=dist(pixels[i],c);n++;});
 return {version:1,cols,rows,palette,matrix,options:{...options},metrics:{meanDeltaE:n?de/n:0,rmse:n?Math.sqrt(se/(3*n)):0},edits:0};
}
function materials(r,spare=10,bag=100){
 if(!Number.isFinite(spare)||spare<0||spare>100||!Number.isInteger(bag)||bag<1||bag>10000)throw Error('备料参数超出范围');
 const counts=new Array(r.palette.length).fill(0);for(const i of r.matrix)if(i>=0)counts[i]++;
 return counts.map((count,i)=>{
  const extra=count*spare/100;
  const prepare=count+Math.ceil(extra-Number.EPSILON*Math.max(1,extra)*4);
  return {...r.palette[i],index:i,count,prepare,bags:Math.ceil(prepare/bag)};
 }).filter(p=>p.count).sort((a,b)=>b.count-a.count||a.index-b.index);
}
const escape=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const csvCell=s=>'"'+String(s).replace(/"/g,'""')+'"';
const safe=s=>/^[=+\-@\t\r]/.test(s)?"'"+s:s;
function csv(r,spare=10,bag=100){
 return '\ufeff'+[['图纸色号','颜色名称','HEX','品牌参考号','实际颗数','含余量备料','每袋颗数','建议袋数'],...materials(r,spare,bag).map(p=>[p.code,safe(p.name),p.hex,safe(p.source_code),p.count,p.prepare,bag,p.bags])].map(a=>a.map(csvCell).join(',')).join('\r\n');
}
function matrixCSV(r){return '\ufeff'+[['行/列',...Array.from({length:r.cols},(_,i)=>i+1)],...Array.from({length:r.rows},(_,y)=>[y+1,...r.matrix.slice(y*r.cols,(y+1)*r.cols).map(i=>i<0?'':r.palette[i].code)])].map(a=>a.map(csvCell).join(',')).join('\r\n');}
function svg(r,{x0=0,y0=0,width=r.cols,height=r.rows,cell=28,labels=true,beads=false,mono=false}={}){
 const margin=30,w=width*cell+60,h=height*cell+60;
 let s=`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}"><rect width="100%" height="100%" fill="#fff"/>`;
 for(let y=0;y<height;y++)for(let x=0;x<width;x++){
  const i=r.matrix[(y+y0)*r.cols+x+x0],px=margin+x*cell,py=margin+y*cell,fill=i<0?'#f6f6f6':mono?'#fff':r.palette[i].hex;
  s+=beads&&i>=0?`<circle cx="${px+cell/2}" cy="${py+cell/2}" r="${cell*.46}" fill="${fill}"/><circle cx="${px+cell/2}" cy="${py+cell/2}" r="${cell*.13}" fill="#f7f5f0"/>`:`<rect x="${px}" y="${py}" width="${cell}" height="${cell}" fill="${fill}"/>`;
  if(labels&&i>=0){const c=rgb(fill),ink=.2126*c[0]+.7152*c[1]+.0722*c[2]<138?'white':'#101010';s+=`<text x="${px+cell/2}" y="${py+cell*.64}" text-anchor="middle" fill="${ink}" font-family="Arial,sans-serif" font-size="${Math.min(10,cell/(r.palette[i].code.length*.68))}">${escape(r.palette[i].code)}</text>`;}
 }
 if(!beads){
  for(let x=0;x<=width;x++)s+=`<path d="M${margin+x*cell} ${margin}v${height*cell}" stroke="#53616a" stroke-width="${(x+x0)%5===0?1.2:.25}"/>`;
  for(let y=0;y<=height;y++)s+=`<path d="M${margin} ${margin+y*cell}h${width*cell}" stroke="#53616a" stroke-width="${(y+y0)%5===0?1.2:.25}"/>`;
 }
 for(let x=0;x<width;x++)if(x===0||x===width-1||(x+x0+1)%5===0)s+=`<text x="${margin+(x+.5)*cell}" y="19" text-anchor="middle" font-family="Arial" font-size="10">${x+x0+1}</text>`;
 for(let y=0;y<height;y++)if(y===0||y===height-1||(y+y0+1)%5===0)s+=`<text x="25" y="${margin+(y+.65)*cell}" text-anchor="end" font-family="Arial" font-size="10">${y+y0+1}</text>`;
 return s+'</svg>';
}
function printHTML(r,spare=10,bag=100,mono=false){
 const ms=materials(r,spare,bag),total=ms.reduce((s,m)=>s+m.count,0);
 let body=`<section><h1>照片转拼豆图纸与材料统计系统</h1><p>${r.cols} 列 × ${r.rows} 行　实际 ${total} 颗　${ms.length} 色　备料余量 ${spare}%</p><p>图纸按 29 × 29 格分区，坐标为全图坐标。空白格不放豆。打印图用于按编号摆放，并非实物 1∶1 模板。</p><p>色卡：${escape(r.paletteName||'自定义')}。图纸编号与品牌参考号请对应下表，制作前核对实物色卡。</p><table><thead><tr><th>色号</th><th>颜色</th><th>HEX</th><th>品牌参考号</th><th>实际</th><th>备料</th><th>袋数</th></tr></thead><tbody>${ms.map(m=>`<tr><td>${escape(m.code)}</td><td>${escape(m.name)}</td><td>${m.hex}</td><td>${escape(m.source_code)}</td><td>${m.count}</td><td>${m.prepare}</td><td>${m.bags}</td></tr>`).join('')}</tbody></table><p>每袋 ${bag} 颗，逐色向上取整。</p></section>`;
 for(let y=0;y<r.rows;y+=29)for(let x=0;x<r.cols;x+=29)body+=`<section><h2>图纸分区 ${Math.floor(y/29)+1} 行 ${Math.floor(x/29)+1} 列</h2><p>全图列 ${x+1}–${Math.min(x+29,r.cols)}，行 ${y+1}–${Math.min(y+29,r.rows)}　${mono?'黑白编号图':'彩色编号图'}</p>${svg(r,{x0:x,y0:y,width:Math.min(29,r.cols-x),height:Math.min(29,r.rows-y),cell:28,mono})}<p>按全图坐标拼接各分区，空格不放豆。</p></section>`;
 return `<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>拼豆打印图纸</title><style>@page{size:A4;margin:14mm}body{font:14px/1.6 "Microsoft YaHei",sans-serif;color:#18272c}section{break-after:page}section:last-child{break-after:auto}svg{max-width:100%;height:auto;max-height:220mm}table{width:100%;border-collapse:collapse;font-size:12px}td,th{padding:4px;border:1px solid #999;text-align:left}tr{break-inside:avoid}thead{display:table-header-group}h1{font-size:23px}h2{font-size:20px}.actions{padding:12px;background:#eee}@media print{.actions{display:none}}</style><div class="actions"><button onclick="window.print()">打印或另存为 PDF</button> 请用 A4 纵向并关闭浏览器页眉页脚。</div>${body}</html>`;
}
function validateProject(r){
 if(!r||r.version!==1||!Number.isInteger(r.cols)||!Number.isInteger(r.rows)||r.cols<1||r.rows<1||r.cols>96||r.rows>96)throw Error('项目尺寸无效');
 const palette=validatePalette(r.palette);
 if(!Array.isArray(r.matrix)||r.matrix.length!==r.cols*r.rows||r.matrix.some(x=>!Number.isInteger(x)||x< -1||x>=palette.length))throw Error('项目矩阵无效');
 return {...r,palette,options:r.options||{},edits:Number(r.edits)||0,metrics:r.metrics||{}};
}
const api={rgb,lab,dist,validatePalette,gridSize,sample,quantize,materials,csv,matrixCSV,svg,printHTML,validateProject};
if(typeof module!=='undefined'&&module.exports)module.exports=api;else root.BeadCore=api;
})(typeof window!=='undefined'?window:globalThis);
