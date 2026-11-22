function report=verify_saved_results
% Recompute representative saved outputs and their CSV metrics without overwriting them.
root=fileparts(fileparts(mfilename('fullpath')));
T=readtable(fullfile(root,'03_实验结果','metrics_all.csv'),'TextType','string');
assert(height(T)==1595 && numel(unique(T.case_id))==275);
cases={'NH17_real','NH34_real','NH37_real','NH17_clear', ...
 'NH17_synthetic_light','NH17_synthetic_medium','NH17_synthetic_dense'};
rows={};
for k=1:numel(cases)
 caseId=cases{k};id=sscanf(caseId,'NH%d_');id=id(1);
 folder=fullfile(root,'03_实验结果','cases',caseId);
 G=dehaze_read_image(fullfile(folder,'reference.png'));
 if contains(caseId,'synthetic')
   beta=.45;if contains(caseId,'medium'),beta=1;elseif contains(caseId,'dense'),beta=1.6;end
   I=synthesize_haze(G,beta,20261021+id,'nonuniform');
 else,I=dehaze_read_image(fullfile(folder,'input.png'));end
 result=dehaze_v2(I);saved=imread(fullfile(folder,'V2.png'));
 assert(isequal(im2uint8(result.final),saved),'Dehaze:Replay','图像不一致 %s',caseId);
 q=paired_quality(saved,G);row=T(T.case_id==caseId & T.method=="V2",:);
 assert(height(row)==1&&abs(q.psnr-row.psnr)<1e-9&&abs(q.ssim-row.ssim)<1e-9);
 rows(end+1,:)={caseId,true,q.psnr,q.ssim}; %#ok<AGROW>
end
report=cell2table(rows,'VariableNames',{'case_id','exact_image_match','psnr','ssim'});
writetable(report,fullfile(root,'07_质量验证','replay.csv'));disp(report);
end
