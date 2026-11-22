function exportResults(result,folder,label)
if nargin<3,label='当前图像';end
if ~isfolder(folder),mkdir(folder);end
for k=1:4,imwrite(result.Images{k},fullfile(folder,[result.Names{k} '.png']));end
T=array2table(result.Metrics,'VariableNames',{'MeanL','StdL','Entropy','ClippedPercent','ChromaShift'});
T.Method=string(result.Names)';T=movevars(T,'Method','Before',1);
writetable(T,fullfile(folder,'指标.csv'),'Encoding','UTF-8');
params=struct('Image',label,'Gamma',result.Gamma,'FusionWeight',result.Alpha,...
    'LuminanceSpan',result.Span,'Options',result.Options,'Note',result.Note);
fid=fopen(fullfile(folder,'参数.json'),'w','n','UTF-8');cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s',jsonencode(params,'PrettyPrint',true));
f=figure('Visible','off','Color','w','Position',[50 50 1400 850]);
tiledlayout(f,2,3,'TileSpacing','compact','Padding','compact');
for k=1:4,nexttile;imshow(result.Images{k});title(result.Names{k},'FontName','Microsoft YaHei');end
nexttile([1 2]);plot(0:255,result.Histograms,'LineWidth',1.2);xlim([0 255]);
xlabel('亮度级');ylabel('概率');legend(result.Names,'Location','best');title('亮度直方图');
exportgraphics(f,fullfile(folder,'四图与直方图.png'),'Resolution',130);close(f);
end
