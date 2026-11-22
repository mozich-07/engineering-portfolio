function folder = export_result(out,folder,reference)
if nargin<3, reference=[]; end
if ~exist(folder,'dir'), mkdir(folder); end
names={'input','sharpenOnly','wiener','learned','final'};
for k=1:numel(names), imwrite(out.(names{k}),fullfile(folder,[names{k} '.png'])); end
if ~isempty(reference), imwrite(reference,fullfile(folder,'reference.png')); end
writetable(out.metrics,fullfile(folder,'metrics.csv'),'Encoding','UTF-8');
meta=rmfield(out,[names {'metrics'}]);
meta.metricNote='PSNR/SSIM/RMSE require paired reference, cropped 12 px; NaN means unavailable. Gradient energy is NOT an accuracy score.';
fid=fopen(fullfile(folder,'parameters.json'),'w','n','UTF-8');
assert(fid>=0,'RestoreLab:Export','无法写入导出目录。');
clean=onCleanup(@()fclose(fid));
fwrite(fid,jsonencode(meta,'PrettyPrint',true),'char');
end
