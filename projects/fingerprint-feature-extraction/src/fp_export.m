function folder = fp_export(R,folder,stem)
if nargin<3,stem='fingerprint';end
stem=regexprep(char(stem),'[<>:"/\\|?*]','_');
folder=fullfile(folder,stem);if ~isfolder(folder),mkdir(folder);end
writetable(R.points,fullfile(folder,'细节点.csv'),'Encoding','UTF-8');
imwrite(R.original,fullfile(folder,'01输入.png'));imwrite(R.enhanced,fullfile(folder,'02增强.png'));
imwrite(R.binary,fullfile(folder,'03二值图.png'));imwrite(R.skeleton,fullfile(folder,'04骨架.png'));
save(fullfile(folder,'分析结果.mat'),'R');
stats=struct('endings',R.endings,'bifurcations',R.bifurcations,'rejected',R.rejected, ...
    'reliableFraction',R.reliableFraction,'seconds',R.seconds,'status',R.status,'options',R.options, ...
    'coordinateNote','sourceX/sourceY map back to imported image. x/y are processed-image coordinates in real mode; x256/y256 are legacy normalized coordinates. Orientation is local ridge direction; accepted is candidate retention, reviewed records manual review.');
if isfield(R,'predictedQuality'),stats.predictedMOS=R.predictedQuality;end
stats.processedSize=size(R.original);stats.meta=R.meta;
fid=fopen(fullfile(folder,'结果摘要.json'),'w','n','UTF-8');fprintf(fid,'%s',jsonencode(stats,PrettyPrint=true));fclose(fid);
f=figure('Visible','off','Color','w','Position',[100 100 1350 760]);tiledlayout(2,3,'Padding','compact');
stages={'original','quality','enhanced','binary','skeleton','points'};
for i=1:6,fp_draw(nexttile,R,stages{i});end
exportgraphics(f,fullfile(folder,'对照总览.png'),'Resolution',130);close(f);
end
