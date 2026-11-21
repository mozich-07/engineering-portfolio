const fs=require('fs'),vm=require('vm'),assert=require('node:assert/strict'),E=require('./engine.js');
const app=fs.readFileSync('work/app.js','utf8'),html=fs.readFileSync('outputs/题库工坊.html','utf8'),body=fs.readFileSync('work/body.html','utf8'),banks=JSON.parse(fs.readFileSync('work/banks.json','utf8'));
const scripts={vendor:'/* Mammoth.js 1.11.0\n'+fs.readFileSync('work/MAMMOTH-LICENSE.txt','utf8')+'\n*/\n'+fs.readFileSync('work/mammoth.browser.min.js','utf8'),engine:fs.readFileSync('work/engine.js','utf8'),application:app};
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
let downloaded;
const ctx={E,esc,window:{APP_BODY:body},document:{getElementById:id=>({textContent:scripts[id]})},$:()=>({textContent:fs.readFileSync('work/style.css','utf8')}),bankBy:id=>banks.find(b=>b.id===id),uuid:()=> '1432D5A1-8D33-482E-A4C0-CC6403143454',download:(name,data)=>{downloaded={name,data};},toast:()=>{}};
vm.createContext(ctx);vm.runInContext(app.slice(app.indexOf('function scriptText('),app.indexOf('function report(')),ctx);
vm.runInContext('exportHTML("xfrm",true)',ctx);
assert.ok(downloaded.data.includes('<tw-storydata '));
fs.writeFileSync('work/exported-twine.html',downloaded.data);
const archive=downloaded.data.slice(downloaded.data.lastIndexOf('<tw-storydata name='), downloaded.data.lastIndexOf('</tw-storydata>')+15);
let format;vm.runInNewContext(fs.readFileSync('work/sugarcube-format.js','utf8'),{window:{storyFormat:x=>format=x}});
assert.equal(format.version,'2.37.3');
const published=format.source.replace(/\{\{STORY_NAME\}\}/g,'Twine Export Test').replace(/\{\{STORY_DATA\}\}/g,()=>archive);
fs.writeFileSync('work/twine-published.html',published);
// Every inline executable script must parse as JavaScript, including scripts in exported portable HTML.
let count=0;for(const m of downloaded.data.matchAll(/<script id="(vendor|engine|application|boot)"[^>]*>([\s\S]*?)<\/script>/g)){new vm.Script(m[2]);count++;}
assert.equal(count,4);console.log('PASS: export roundtrip, Twine archive metadata, portable JavaScript syntax');
if(process.argv.includes('--deliver')){
 for(const bank of banks){vm.runInContext('exportHTML('+JSON.stringify(bank.id)+',true)',ctx);fs.writeFileSync('outputs/'+downloaded.name,downloaded.data);}
}
