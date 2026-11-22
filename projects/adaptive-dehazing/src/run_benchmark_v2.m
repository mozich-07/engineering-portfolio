function T=run_benchmark_v2(root,mode)
% Full reproducible protocol. No per-image quality-based method selection.
if nargin<1,root=fileparts(fileparts(mfilename('fullpath')));end
if nargin<2,mode='all';end
addpath(fullfile(root,'01_程序'));
data=fullfile(root,'02_数据集');out=fullfile(root,'03_实验结果');if ~isfolder(out),mkdir(out);end
groups=jsondecode(fileread(fullfile(data,'scene_groups.json')));
M=readtable(fullfile(data,'manifest.csv'),'TextType','string');
rows={};caseRows={};total=0;
ids=1:55;if strcmp(mode,'development'),ids=1:15;end
for id=ids
 G=dehaze_read_image(fullfile(data,'NH-HAZE_640',sprintf('%02d_GT.png',id)));
 H=dehaze_read_image(fullfile(data,'NH-HAZE_640',sprintf('%02d_hazy.png',id)));
 split='development';if ismember(id,groups.test),split='test';end
 group=char(M.group_id(find(M.scene_id==sprintf('NH%02d',id),1)));
 cases={'real','clear','synthetic_light','synthetic_medium','synthetic_dense'};
 for ci=1:numel(cases)
    betas=[.45 1 1.6];
    if ci==1,I=H;elseif ci==2,I=G;else,I=synthesize_haze(G,betas(ci-2),20261021+id,'nonuniform');end
    caseId=sprintf('NH%02d_%s',id,cases{ci});caseDir=fullfile(out,'cases',caseId);if ~isfolder(caseDir),mkdir(caseDir);end
    imwrite(I,fullfile(caseDir,'input.png'));imwrite(G,fullfile(caseDir,'reference.png'));
    start=tic;r=dehaze_v2(I);seconds=toc(start);
    imwrite(r.final,fullfile(caseDir,'V2.png'));imwrite(r.baseline,fullfile(caseDir,'V1.png'));
    if ci==1
       imwrite(r.mainTransmission,fullfile(caseDir,'main_transmission.png'));
       imwrite(r.transmission,fullfile(caseDir,'residual_transmission.png'));
       imwrite(r.skyConfidence,fullfile(caseDir,'sky_confidence.png'));
       imwrite(r.strengthMap,fullfile(caseDir,'strength_map.png'));
    end
    lab=rgb2lab(I);lab(:,:,1)=100*adapthisteq(lab(:,:,1)/100,'ClipLimit',.01);clahe=max(0,min(1,lab2rgb(lab)));
    names={'Input','CLAHE','MATLAB_DCP','V1','V2'};
    outputs={I,clahe,imreducehaze(I,'Method','approxdcp','ContrastEnhancement','none'),r.baseline,r.final};
    for k=1:numel(names)
       q=paired_quality(outputs{k},G);dur=NaN;if k==5,dur=seconds;end
       rows(end+1,:)={caseId,id,group,split,cases{ci},names{k},q.psnr,q.ssim,q.mae,q.clipped,dur}; %#ok<AGROW>
       if ci==1,imwrite(outputs{k},fullfile(caseDir,[names{k} '.png']));end
    end
    % Ablations share the main restoration and differ only by named switches.
    if ci==1
       abnames={'V2_no_sky','V2_no_refine','V2_no_guard','V2_no_residual'};
       configs={struct('skyProtection',0),struct('refine',false),struct('guard',false),struct('residual',false)};
       for k=1:numel(abnames)
          a=dehaze_v2(I,configs{k});q=paired_quality(a.final,G);
          rows(end+1,:)={caseId,id,group,split,cases{ci},abnames{k},q.psnr,q.ssim,q.mae,q.clipped,NaN}; %#ok<AGROW>
          imwrite(a.final,fullfile(caseDir,[abnames{k} '.png']));
       end
    end
    total=total+1;fprintf('%d %s %s V2 %.2fs\n',total,split,caseId,seconds);
 end
 % Checkpoint preserves completed scenes and permits diagnosis after interruption.
 T=cell2table(rows,'VariableNames',{'case_id','scene_id','group_id','split','condition','method','psnr','ssim','mae','clipped_fraction','seconds'});
 writetable(T,fullfile(out,['metrics_' mode '.csv']));
end
T=cell2table(rows,'VariableNames',{'case_id','scene_id','group_id','split','condition','method','psnr','ssim','mae','clipped_fraction','seconds'});
writetable(T,fullfile(out,['metrics_' mode '.csv']));
fprintf('BENCHMARK DONE %d rows\n',height(T));
end
