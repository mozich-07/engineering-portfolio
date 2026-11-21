(function(root){
'use strict';
const norm = s => String(s??'').replace(/[Ａ-Ｚａ-ｚ０-９]/g,c=>String.fromCharCode(c.charCodeAt(0)-65248)).replace(/\r/g,'').trim();
const canonical = s => [...new Set(norm(s).toUpperCase().replace(/[^A-H]/g,''))].sort().join('');
function hash(s){let h=2166136261;for(const c of s){h^=c.charCodeAt(0);h=Math.imul(h,16777619);}return (h>>>0).toString(36);}
function identity(q){return JSON.stringify([q.stem,q.opts,q.media]);}
function answer(raw,opts){
 const s=norm(raw).replace(/[。；;.,，\s]+$/,'');
 if(/^(正确|对|√|✓|是|true)$/i.test(s))return opts.find(o=>/^(正确|对[。]?|是|√|✓)$/.test(o.t.trim()))?.l||'';
 if(/^(错误|错|×|✗|否|false)$/i.test(s))return opts.find(o=>/^(错误|错[。]?|否|×|✗)$/.test(o.t.trim()))?.l||'';
 return /^[A-Ha-h\s、,，/;；+和及]+$/.test(s)?canonical(s):'';
}
function issues(q){
 const e=[];
 if(!q.stem?.trim())e.push('题干为空');
 if(q.opts.length<2)e.push('缺少选项（或是不支持自动判分的题型）');
 if(q.opts.some(o=>!o.t?.trim()&&!o.img&&!o.images?.length))e.push('有空选项');
 if(new Set(q.opts.map(o=>o.l)).size!==q.opts.length)e.push('选项字母重复');
 if(q.opts.some(o=>!/^[A-H]$/.test(o.l)))e.push('选项字母应为 A–H');
 if(!q.ans)e.push('未识别到明确答案');
 if([...q.ans].some(c=>!q.opts.some(o=>o.l===c)))e.push('答案对应的选项不存在');
 if(q.kind==='single'&&q.ans.length>1)e.push('单选题存在多个答案');
 return [...new Set(e)];
}
function parse(text,images=[]){
 let input=norm(text), category='未分类',kind='',q=null,part='stem',keys=false;
 const questions=[],warnings=[],answerKeys=[],unmatched=[];
 input=input.replace(/\t/g,'  ')
   .replace(/([^\n])\s*(【?(?:正确答案|参考答案|答案)】?\s*[:：])/g,'$1\n$2')
   .replace(/([^\n])\s*(【?(?:解析|答案解析|解答|说明)】?\s*[:：])/g,'$1\n$2')
   .replace(/([^\n])(?:[ \u3000]+)([A-H][.．、:：)）])/g,'$1\n$2');
 const flush=()=>{if(q){questions.push(q);q=null;}};
 const add=(s)=>{
   const urls=[];s=s.replace(/\[\[IMG:(\d+)\]\]/g,(_,n)=>{if(images[+n])urls.push(images[+n]);return '';}).trim();
   if(part==='opt'&&q.opts.length){const o=q.opts.at(-1);o.t+=(o.t&&s?'\n':'')+s;o.images.push(...urls);}
   else if(part==='note'){q.note+=(q.note&&s?'\n':'')+s;if(urls.length)q.media.push(...urls);}
   else{q.stem+=(q.stem&&s?'\n':'')+s;q.media.push(...urls);}
 };
 for(let line of input.split('\n').map(norm).filter(Boolean)){
   if(/^(?:参考答案|答案汇总|答案表|答案)\s*[:：]?$/.test(line)){flush();keys=true;continue;}
   if(keys){
     const matches=[...line.matchAll(/(?:第)?(\d+)(?:题)?[.、:：)）\s]+([A-Ha-h]+|正确|错误|对|错|√|×)(?=\s|[，,；;]|$)/g)];
     if(matches.length){answerKeys.push(...matches.map(m=>[m[1],m[2]]));continue;}
     warnings.push('答案表中有未识别内容：'+line.slice(0,90));continue;
   }
   if(/^(?:[一二三四五六七八九十\d]+[、.．]\s*)?(?:[【\[])?(?:单项选择题|单选题|多项选择题|多选题|判断题)(?:[】\]])?(?:\s*[（(].*[）)])?$/.test(line)){
     flush();category=line;kind=/多/.test(line)?'multi':/判断/.test(line)?'tf':'single';continue;
   }
   const start=line.match(/^(?:第\s*(\d+)\s*题\s*[:：.、]?|[（(](\d+)[）)]|(?:(\d+)[、．.)）](?!\d)))\s*(.*)$/);
   if(start){flush();q={number:start[1]||start[2]||start[3],cat:category,kind,stem:'',opts:[],ans:'',rawAnswer:'',note:'',media:[],source:line};part='stem';line=start[4];}
   if(!q){unmatched.push(line);continue;}
   const a=line.match(/^[【\[]?(?:正确答案|参考答案|答案)[】\]]?\s*[:：]\s*(.*)$/);
   if(a){q.rawAnswer=a[1].replace(/[）)]$/,'');part='answer';continue;}
   const n=line.match(/^[【\[]?(?:解析|答案解析|解答|说明)[】\]]?\s*[:：]\s*(.*)$/);
   if(n){part='note';add(n[1]);continue;}
   const o=line.match(/^([A-H])[.．、:：)）]\s*(.*)$/i);
   if(o){q.opts.push({l:o[1].toUpperCase(),t:'',images:[]});part='opt';add(o[2]);continue;}
   if(part==='answer'){warnings.push('第 '+q.number+' 题答案后有未分类文字：'+line.slice(0,70));q.note+=(q.note?'\n':'')+line;continue;}
   add(line);
 }
 flush();
 for(const [n,a] of answerKeys){const matches=questions.filter(x=>x.number===n);if(matches.length===1){if(matches[0].rawAnswer&&norm(matches[0].rawAnswer)!==norm(a)){matches[0].conflict=true;warnings.push('第 '+n+' 题正文答案与答案表不同，请核对');}else matches[0].rawAnswer=a;}else warnings.push('答案表题号 '+n+' 无法唯一匹配');}
 const seen=new Map();let duplicates=0;
 for(const q of questions){
   if(!q.rawAnswer){const m=q.stem.match(/[（(]\s*([A-H]{1,8}|正确|错误|对|错|√|×)\s*[）)]\s*$/i);if(m){q.rawAnswer=m[1];q.stem=q.stem.slice(0,m.index).trim();}}
   if(!q.opts.length&&(q.kind==='tf'||/^(正确|错误|对|错|√|×|true|false)$/i.test(q.rawAnswer))){q.opts=[{l:'A',t:'正确',images:[]},{l:'B',t:'错误',images:[]}];q.kind='tf';}
   q.ans=answer(q.rawAnswer,q.opts);q.kind=q.kind||(q.ans.length>1?'multi':'single');
   q.id='q_'+hash(identity(q));q.errors=issues(q);if(q.conflict)q.errors.push('正文答案与答案表冲突');
   const key=identity(q);if(seen.has(key)){const old=seen.get(key);q.duplicate=true;duplicates++;if(old.ans!==q.ans){old.errors.push('重复题答案冲突');q.errors.push('重复题答案冲突');q.duplicate=false;}}else seen.set(key,q);
 }
 if(unmatched.length)warnings.push('题号之前有 '+unmatched.length+' 行文字未作为题目导入，可在原文中核对。');
 return {questions,warnings,duplicates,unmatched,source:input};
}
function totals(session){const all=session.ids.map(id=>session.answers[id]);const answered=all.filter(Boolean),right=answered.filter(a=>a.ok).length;return {total:all.length,answered:answered.length,right,wrong:answered.length-right,unanswered:all.length-answered.length,score:all.length?Math.round(100*right/all.length):0,accuracy:answered.length?Math.round(100*right/answered.length):0};}
function record(stats,qid,pick,correct,threshold=2){const old=stats[qid]||{attempts:0,wrong:0,streak:0,active:false,everWrong:false};const ok=canonical(pick)===canonical(correct);const next={...old,attempts:old.attempts+1,lastPick:canonical(pick),lastAt:Date.now(),lastCorrect:ok};if(ok){next.streak=old.streak+1;if(next.active&&next.streak>=threshold)next.active=false;}else{next.wrong++;next.streak=0;next.active=true;next.everWrong=true;}stats[qid]=next;return ok;}
const api={norm,canonical,hash,identity,answer,issues,parse,totals,record};
if(typeof module!=='undefined'&&module.exports)module.exports=api;else root.QEngine=api;
})(typeof window!=='undefined'?window:globalThis);
