function fp_evaluate(root)
S=load(fullfile(root,'models','quality_model.mat'));model=S.model;
T=readtable(fullfile(root,'results','case_manifest.csv'),'TextType','string');
test=T(T.split=="test",:);rows=cell(0,13);
fprintf('Evaluate %d independent test images\n',height(test));
for i=1:height(test)
    R=fp_process(fullfile(root,test.file(i)),model);
    M=imread(fullfile(root,replace(test.file(i),'.png','_mask.png')))>0;
    predicted=R.quality>=model.threshold & R.mask;truth=M&R.mask;
    P=R.points;ids=sub2ind([256 256],P.y256,P.x256);affected=M(ids);
    union=nnz(predicted|truth);if union==0,iou=1;else,iou=nnz(predicted&truth)/union;end
    rows(end+1,:)={test.subject(i),char(test.kind(i)),char(test.file(i)),height(P), ...
        nnz(P.accepted),nnz(affected),nnz(affected & P.accepted),nnz(~affected), ...
        nnz(~affected & P.accepted),iou,R.seconds,R.endings,R.bifurcations}; %#ok<AGROW>
    if mod(i,40)==0,fprintf('Processed %d/%d\n',i,height(test));end
end
E=cell2table(rows,'VariableNames',{'subject','kind','file','baselineCandidates','acceptedCandidates', ...
    'affectedBefore','affectedAfter','unaffectedBefore','unaffectedAfter','maskIoU','seconds','endings','bifurcations'});
writetable(E,fullfile(root,'results','image_evaluation.csv'),'Encoding','UTF-8');
summary=struct('imageCount',height(E),'affectedBefore',sum(E.affectedBefore),'affectedAfter',sum(E.affectedAfter), ...
    'unaffectedRetention',sum(E.unaffectedAfter)/max(1,sum(E.unaffectedBefore)), ...
    'affectedSuppression',1-sum(E.affectedAfter)/max(1,sum(E.affectedBefore)), ...
    'meanSeconds',mean(E.seconds),'meanMaskIoU',mean(E.maskIoU),'note','Mask overlap and affected-region suppression are synthetic degradation metrics, NOT ground-truth minutiae precision/recall.');
fid=fopen(fullfile(root,'results','pipeline_metrics.json'),'w','n','UTF-8');fprintf(fid,'%s',jsonencode(summary,PrettyPrint=true));fclose(fid);
% Demo subset is selected deterministically by subject ID, never by test success.
subjects=unique(test.subject);selected=subjects(1:4);D=test(ismember(test.subject,selected),:);
demos=cell(0,4);labels={'原始指纹','模拟粉尘','模拟遮盖','模拟模糊'};kinds={'clean','dust','occlusion','blur'};
for i=1:height(D)
    idx=find(strcmp(kinds,D.kind(i)));demos(end+1,:)={char(D.file(i)),sprintf('%03d %s',D.subject(i),labels{idx}),'独立测试主体；粉尘等为人工扰动',D.subject(i)}; %#ok<AGROW>
end
external=dir(fullfile(root,'data','external','591_*.bmp'));
for i=1:numel(external)
    label=erase(external(i).name,'.bmp');demos(end+1,:)={['data/external/' external(i).name],['发布方案例 ' label],'SOCOFing 发布方原图或合成损伤；未参与训练',591}; %#ok<AGROW>
end
for name={'bad','good','ugly'}
    rel=['data/external/nist_' name{1} '_crop.png'];
    if isfile(fullfile(root,rel))
        demos(end+1,:)={rel,['真实潜指纹 ' name{1} '（困难案例）'],'NIST SD27 经 MSU 公开示例；已裁剪，含背景干扰；只作域外定性演示',0}; %#ok<AGROW>
    end
end
DT=cell2table(demos,'VariableNames',{'file','label','provenance','subject'});writetable(DT,fullfile(root,'data','demo_manifest.csv'),'Encoding','UTF-8');
gallery=fullfile(root,'results','gallery');if ~isfolder(gallery),mkdir(gallery);end
html="<!doctype html><html lang='zh-CN'><meta charset='utf-8'><title>指纹案例结果图册</title><style>body{font:16px Microsoft YaHei;max-width:1200px;margin:40px auto;color:#172b40}img{width:100%}section{margin:36px 0}p{line-height:1.8}</style><h1>指纹案例结果图册</h1><p>本页为已保存的计算结果，现场计算请启动 MATLAB 程序。蓝色圆圈为端点，红色三角为分叉，灰叉为被质量模型抑制的候选点。评分指向模拟受扰动特征，不代表司法鉴定可靠度。</p>";
for i=1:height(DT)
    R=fp_process(fullfile(root,DT.file{i}),model);stem=sprintf('case_%02d',i);fp_export(R,gallery,stem);
    html=html+"<section><h2>"+string(DT.label{i})+"</h2><p>"+string(DT.provenance{i})+"</p><img src='"+stem+"/对照总览.png'><p>"+string(R.status)+"</p></section>";
end
fid=fopen(fullfile(gallery,'index.html'),'w','n','UTF-8');fprintf(fid,'%s',html+"</html>");fclose(fid);
disp(summary);
end
