function folder=fx_export(r,model,out)
c=fx_config();if nargin<3,out=fullfile(c.root,'exports');end
if ~isfolder(out),mkdir(out);end
[~,uid]=fileparts(tempname);folder=fullfile(out,[char(datetime('now','Format','yyyyMMdd_HHmmss')) '_' uid]);mkdir(folder);
imwrite(r.image,fullfile(folder,'query.png'));
k=r.rank(:);writetable(table((1:102)',model.classes.Display(k),r.probabilities(k)', ...
 'VariableNames',{'Rank','Class','CalibratedScore'}),fullfile(folder,'classification.csv'),'Encoding','UTF-8');
neighbors=r.neighbors;neighbors.Class=model.classes.Display(neighbors.Label);neighbors.Distance=r.distances;
writetable(neighbors,fullfile(folder,'retrieval.csv'),'Encoding','UTF-8');
summary=struct('prediction',r.name,'score',r.topScores(1),'needsReview',r.review,'runId',r.runId,'seconds',r.seconds, ...
 'note','分数经过验证集温度缩放，仍可能失准；低分提示不能识别所有未知类别。');
writelines(jsonencode(summary,'PrettyPrint',true),fullfile(folder,'summary.json'));
f=figure('Visible','off','Color','w','Position',[50 50 1100 560]);tiledlayout(2,4,'Padding','compact','TileSpacing','compact');
nexttile;imshow(r.image);title('查询图片');nexttile;imshow(r.edge);title('边缘预览');
for i=1:6,nexttile;imshow(fx_read(fullfile(c.root,r.neighbors.Path(i))));title({char(model.classes.Display(r.neighbors.Label(i))),sprintf('距离 %.3f',r.distances(i))},'Interpreter','none','FontSize',9);end
sgtitle(char(r.name),'Interpreter','none');exportgraphics(f,fullfile(folder,'result.png'),'Resolution',140);close(f);
end
