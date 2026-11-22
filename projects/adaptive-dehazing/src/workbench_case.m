function result=workbench_case(inputPath,outDir,options,referencePath,meta)
%WORKBENCH_CASE Practical application adapter. Frozen V2 is called unchanged.
if nargin<5,meta=struct;end
if nargin<4,referencePath='';end
if ~isfolder(outDir),mkdir(outDir);end
progress('loading','读取与校验图像',0.10);
I=dehaze_read_image(inputPath);originalSize=size(I);s=min(1,640/max(size(I,[1 2])));
if s<1,I=imresize(I,s);end
I=im2double(im2uint8(I)); % Output and paired measures use the same quantized input.
progress('processing','正在执行原版主处理与区域残余校正',0.30);
tic;r=dehaze_v2(I,options);seconds=toc;
progress('analysis','计算图像统计并保存中间结果',0.80);
files=struct('input','input.png','final','V2.png','baseline','V1.png', ...
 'retinex','retinex.png','dcp','DCP.png','dark','dark.png', ...
 'mainTransmission','main_transmission.png','transmission','residual_transmission.png', ...
 'sky','sky.png','strength','strength.png');
imwrite(im2uint8(I),fullfile(outDir,files.input));
imwrite(im2uint8(r.final),fullfile(outDir,files.final));
imwrite(im2uint8(r.baseline),fullfile(outDir,files.baseline));
imwrite(im2uint8(r.retinex),fullfile(outDir,files.retinex));
imwrite(im2uint8(r.dcp),fullfile(outDir,files.dcp));
imwrite(im2uint8(r.darkChannel),fullfile(outDir,files.dark));
imwrite(im2uint8(r.mainTransmission),fullfile(outDir,files.mainTransmission));
imwrite(im2uint8(r.transmission),fullfile(outDir,files.transmission));
imwrite(im2uint8(r.skyConfidence),fullfile(outDir,files.sky));
imwrite(im2uint8(r.strengthMap),fullfile(outDir,files.strength));
stats=struct('input',measure(I),'final',measure(r.final),'baseline',measure(r.baseline));
quality=[];
if ~isempty(referencePath)
 G=dehaze_read_image(referencePath);
 if s<1,G=imresize(G,s);end
 if ~isequal(size(G),size(I)),error('Workbench:Reference','参考图尺寸不一致，拒绝计算配对指标。');end
 imwrite(im2uint8(G),fullfile(outDir,'reference.png'));files.reference='reference.png';
 quality=struct('input',paired_quality(I,G),'baseline',paired_quality(r.baseline,G),'final',paired_quality(r.final,G));
end
result=struct('version','workbench-1.0','meta',meta,'files',files,'options',r.options, ...
 'originalWidth',originalSize(2),'originalHeight',originalSize(1), ...
 'width',size(I,2),'height',size(I,1),'seconds',seconds,'stats',stats,'quality',quality, ...
 'inputGate',r.inputGate,'atmosphere',r.mainAtmosphere,'residualAtmosphere',r.atmosphericLight, ...
 'transmissionMean',mean(r.mainTransmission(:)),'skyMean',mean(r.skyConfidence(:)), ...
 'warning',r.warning,'status',r.status,'created',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
writejson(fullfile(outDir,'result.json'),result);
fid=fopen(fullfile(outDir,'分析记录.txt'),'w','n','UTF-8');cl=onCleanup(@()fclose(fid));
fprintf(fid,'去雾工作台 · 实际处理记录\n输入：%s\n工作分辨率：%d × %d（长边不超过 640 px）\n算法：原版 V1 主阶段 + V2 区域残余校正\n算法耗时：%.4f 秒（不含启动、读取、导出）\n整体门控：%.4f\n参数：%s\n警告：%s\n',inputPath,result.width,result.height,seconds,r.inputGate,jsonencode(r.options),r.warning);
fprintf(fid,'\n已执行：读取校验 → Retinex/暗通道主处理 → 区域残余校正 → 统计与导出。\n亮度、对比度、熵和边缘变化是描述性指标，不能单独证明去雾质量。\n暗通道不是雾浓度；透射率不是实测深度；天空置信度不是语义分割结果。\n');
if isempty(quality),fprintf(fid,'无同场景清晰参考图，不计算 PSNR/SSIM。\n');else,fprintf(fid,'配对指标（uint8 RGB PSNR、灰度 SSIM）：%s\n',jsonencode(quality));end
if isfield(meta,'source'),fprintf(fid,'\n来源：%s\n',string(meta.source));end
if isfield(meta,'page'),fprintf(fid,'原始来源：%s\n',string(meta.page));end
if isfield(meta,'artist'),fprintf(fid,'作者：%s\n',string(meta.artist));end
if isfield(meta,'license'),fprintf(fid,'许可：%s\n',string(meta.license));end
if isfield(meta,'license_url'),fprintf(fid,'许可链接：%s\n',string(meta.license_url));end
fprintf(fid,'修改：缩放、去雾及派生可视化。CC BY-SA 图片的处理结果遵循原图相同许可；未声明开放许可的数据不要公开再分发。\n');
progress('complete','处理完成',1);
 function progress(state,message,fraction)
  writejson(fullfile(outDir,'status.json'),struct('state',state,'message',message,'progress',fraction));
 end
end
function m=measure(I)
I=im2double(im2uint8(I));g=rgb2gray(I);[gx,gy]=imgradientxy(g,'sobel');
counts=histcounts(g(:),linspace(0,1,33));
m=struct('brightness',mean(g(:)),'contrast',std(g(:),1),'entropy',entropy(im2uint8(g)), ...
 'edge',mean(hypot(gx(:),gy(:))),'clipped',mean(any(I<=0|I>=1,3),'all'), ...
 'histogram',counts,'p05',prctile(g(:),5),'p95',prctile(g(:),95));
end
function writejson(path,value)
tmp=[path '.tmp'];fid=fopen(tmp,'w','n','UTF-8');assert(fid>=0,'无法保存处理结果');
fprintf(fid,'%s',jsonencode(value));fclose(fid);movefile(tmp,path,'f');
end
