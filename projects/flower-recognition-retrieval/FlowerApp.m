function app=FlowerApp(visible)
% Simple native MATLAB app using the reused GitHub network.
if nargin<1,visible='on';end
root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'src'));c=fx_config();[model,runFolder]=fx_load();
[manifest,classes,audit]=fx_prepare();preds=readtable(fullfile(runFolder,'test_predictions.csv'),'TextType','string');
currentPath="";result=[];sampleIndex=0;lastExport="";busy=false;green=[.10 .36 .27];
fig=uifigure('Name','光纤通信大作业 · 花卉识别与检索','Position',[70 40 1300 850],'Visible',visible,'Color',[.96 .97 .96]);
layout=uigridlayout(fig,[2 1]);layout.RowHeight={62,'1x'};layout.Padding=[18 12 18 14];
head=uigridlayout(layout,[1 2]);head.ColumnWidth={'1x',450};head.Padding=[0 0 0 0];
uilabel(head,'Text','花卉识别与相似图检索','FontName','Microsoft YaHei','FontSize',27,'FontWeight','bold','FontColor',green);
uilabel(head,'Text',sprintf('102 类 / %d 张原图 / 测试准确率 %.2f%%',audit.rawCount,100*model.metrics.accuracy),'FontSize',15,'HorizontalAlignment','right');
tabs=uitabgroup(layout);tab1=uitab(tabs,'Title','识别与检索');tab2=uitab(tabs,'Title','数据与训练');tab3=uitab(tabs,'Title','模型评估');tab4=uitab(tabs,'Title','实验总览');
g=uigridlayout(tab1,[1 2]);g.ColumnWidth={260,'1x'};g.Padding=[10 10 10 10];g.ColumnSpacing=16;
side=uigridlayout(g,[11 1]);side.RowHeight={28,35,40,40,46,40,40,38,'1x',80,44};side.Padding=[6 6 6 6];
uilabel(side,'Text','选择图片','FontSize',19,'FontWeight','bold');
classDrop=uidropdown(side,'Items',cellstr(classes.Display),'ItemsData',1:102,'Value',54,'FontSize',13,'ValueChangedFcn',@(~,~)resetSample());
sample=uibutton(side,'Text','载入该类测试样例','FontSize',14,'ButtonPushedFcn',@(~,~)loadSample());
chooseButton=uibutton(side,'Text','选择自己的图片','FontSize',14,'ButtonPushedFcn',@(~,~)choose());
runButton=uibutton(side,'Text','识别并检索','FontSize',16,'FontWeight','bold','BackgroundColor',green,'FontColor',[1 1 1], ...
 'Enable','off','ButtonPushedFcn',@(~,~)recognize());
export=uibutton(side,'Text','导出结果','FontSize',14,'Enable','off','ButtonPushedFcn',@(~,~)saveResult());
batchButton=uibutton(side,'Text','批量识别文件夹','FontSize',14,'ButtonPushedFcn',@(~,~)batch());
openExport=uibutton(side,'Text','打开导出目录','FontSize',14,'Enable','off','ButtonPushedFcn',@(~,~)openOutput());
uilabel(side,'Text','分类分数经验证集校准，仍可能失准。低分结果建议人工复核。','FontSize',13,'WordWrap','on');
uilabel(side,'Text',sprintf('训练库检索 · 六张相似图片\n支持 102 个数据集类别。\n其他植物或非花图片可能误判。'),'FontSize',13,'WordWrap','on');
uilabel(side,'Text',['模型版本 ' model.runId],'FontSize',12,'FontColor',green);
main=uigridlayout(g,[4 1]);main.RowHeight={'1x',62,158,180};main.Padding=[0 0 0 0];
preview=uigridlayout(main,[1 3]);preview.Padding=[0 0 0 0];axes1=gobjects(1,3);
titles={'输入照片','灰度预览','边缘预览'};
for i=1:3,axes1(i)=uiaxes(preview);axis(axes1(i),'off');axes1(i).Toolbar.Visible='off';title(axes1(i),titles{i});end
summary=uigridlayout(main,[2 1]);summary.RowHeight={30,'1x'};summary.Padding=[4 0 4 0];
prediction=uilabel(summary,'Text','载入图片后开始识别','FontSize',21,'FontWeight','bold');
status=uilabel(summary,'Text','左侧可浏览 102 类独立测试样例，也可导入自己的照片。','FontSize',13,'WordWrap','on');
scoreTable=uitable(main,'ColumnName',{'排名','候选类别','校准后分数'},'ColumnWidth',{55,'auto',125},'RowName',{},'FontSize',13);
gallery=uigridlayout(main,[1 6]);gallery.Padding=[0 0 0 0];gallery.ColumnSpacing=5;ga=gobjects(1,6);
for i=1:6,ga(i)=uiaxes(gallery);axis(ga(i),'off');ga(i).Toolbar.Visible='off';end
data=uigridlayout(tab2,[4 1]);data.RowHeight={75,300,'1x',56};data.Padding=[18 16 18 16];
uilabel(data,'Text',sprintf('原始 %d 张 / 有效 %d 张 / 102 类\n训练 %d / 验证 %d / 测试 %d；分组划分，冻结主干，仅训练分类器。', ...
 audit.rawCount,audit.includedCount,audit.trainCount,audit.validationCount,audit.testCount),'FontSize',17,'FontWeight','bold');
counts=zeros(102,3);splits=["train","validation","test"];
for k=1:102,for j=1:3,counts(k,j)=sum(manifest.Label==k & manifest.Split==splits(j));end,end
uitable(data,'Data',table(classes.Display,counts(:,1),counts(:,2),counts(:,3)), ...
 'ColumnName',{'花卉类别','训练原图','验证原图','测试原图'},'ColumnWidth',{'auto',160,160,160},'RowName',{},'FontSize',13);
uitextarea(data,'Editable','off','FontSize',15,'Value',{ ...
 '机器学习流程';'1. 原图检查、SHA-256 去重与近重复分组。'; ...
 '2. 训练集拟合标准化和分类器；仅训练新分类头，避免重复计算主干。'; ...
 '3. 比较传统特征 SVM、ResNet18 特征 SVM 和冻结主干分类头。'; ...
 '4. 验证集选择模型、校准分数；锁定后评估独立测试集。'; ...
 '5. 保存模型，提供分类、训练库检索、批量处理及结果导出。'; ...
 ''; '复用：MathWorks GitHub ResNet-18 网络及 ImageNet 预训练参数。'; ...
 '自定义约 60/20/20 分组划分，不能直接与 Oxford 官方榜单比较。'; ...
 '正常使用无需重训。重新训练时，在 MATLAB 命令窗口查看进度。'});
actions=uigridlayout(data,[1 3]);actions.ColumnWidth={220,220,'1x'};
retrain=uibutton(actions,'Text','重新训练（耗时操作）','FontSize',14,'ButtonPushedFcn',@(~,~)trainAgain());
uibutton(actions,'Text','查看当前训练曲线','FontSize',14,'ButtonPushedFcn',@(~,~)showPlot('training_curves.png'));
uilabel(actions,'Text','源码、训练记录与模型均随项目提供。','FontSize',13);
ev=uigridlayout(tab3,[5 1]);ev.RowHeight={75,185,46,'1x',48};ev.Padding=[16 12 16 12];m=model.metrics;
uilabel(ev,'Text',sprintf('准确率 %.2f%% / Top-5 %.2f%% / Macro-F1 %.3f / 检索 P@5 %.2f%%\n95%% 准确率区间 [%.2f%%, %.2f%%]；指标来自本地独立测试。', ...
 100*m.accuracy,100*m.top5,m.macroF1,100*m.retrievalP5,100*m.accuracyCI),'FontSize',16,'FontWeight','bold');
M=model.comparison;
names=["传统颜色纹理特征 + SVM";"ResNet18 特征 + SVM λ=0.001";"ResNet18 特征 + SVM λ=0.01";"冻结 ResNet18 + 学习分类头"];
display=table(names,round(100*M.ValidationAccuracy,2),round(100*M.TestAccuracy,2),round(M.TestMacroF1,3));
uitable(ev,'Data',display,'ColumnName',{'模型方案','验证准确率 %','测试准确率 %','测试 Macro-F1'},'ColumnWidth',{'auto',170,170,170},'RowName',{},'FontSize',13);
selector=uidropdown(ev,'Items',{'训练损失与准确率','学习曲线','模型对比','102 类混淆矩阵','分数校准图'},'ValueChangedFcn',@(~,~)changeChart());
chart=uiaxes(ev);chart.Toolbar.Visible='off';axis(chart,'off');changeChart();
bottom=uigridlayout(ev,[1 2]);bottom.ColumnWidth={260,'1x'};
uibutton(bottom,'Text','查看真实误判案例','FontSize',14,'ButtonPushedFcn',@(~,~)loadError());
uilabel(bottom,'Text','直接读取测试误判记录，不用挑选的成功样例代替测试成绩。','FontSize',13);
course=uigridlayout(tab4,[4 1]);course.RowHeight={55,205,'1x',45};course.Padding=[22 18 22 18];
uilabel(course,'Text','基于迁移学习的花卉图像识别与检索','FontSize',24,'FontWeight','bold','FontColor',green);
uitable(course,'Data',{'意义','辅助整理花卉照片，为人工辨识提供类别候选和相似图片'; ...
 '任务','102 类分类、训练图库检索、批量处理和结果导出'; ...
 '原理','图像预处理与特征提取，训练分类器，验证集选型后独立测试'; ...
 '验证',sprintf('测试 %d 张，准确率 %.2f%%，Macro-F1 %.4f，检索 P@5 %.2f%%',m.testCount,100*m.accuracy,m.macroF1,100*m.retrievalP5); ...
 '应用边界','支持数据集内类别，低分和不合理结果需要人工复核'}, ...
 'ColumnName',{'环节','项目内容'},'ColumnWidth',{100,'auto'},'RowName',{},'FontSize',15);
uitextarea(course,'Editable','off','FontSize',16,'Value',{ ...
 '机器学习过程与证据'; ...
 '1. 数据审计：8189 张原图，排除 4 张重复图；近重复候选成组划分。'; ...
 '2. 数据隔离：训练 4868 张，验证 1639 张，独立测试 1678 张。'; ...
 '3. 学习参数：标准化仅由训练集拟合；比较 SVM 与新分类头。'; ...
 '4. 验证选型：用验证 Macro-F1 锁定方案，保存 selection_locked.json。'; ...
 '5. 定量分析：准确率、Macro-F1、Top-5、P@5 和全部逐图记录。'; ...
 '6. 定性展示：成功样例、真实误判和相似检索，均可在界面查看。'});
courseActions=uigridlayout(course,[1 2]);courseActions.ColumnWidth={245,'1x'};
evidenceButton=uibutton(courseActions,'Text','复核并导出实验摘要','FontSize',15,'ButtonPushedFcn',@(~,~)exportEvidence());
evidenceStatus=uilabel(courseActions,'Text','读取逐图记录复算指标，不重新训练。','FontSize',14);
app=struct('Figure',fig,'Load',@loadImage,'Run',@recognize,'Export',@saveResult,'Result',@getResult,'SelectTab',@selectTab, ...
 'Controls',struct('Run',runButton,'Export',export,'Sample',sample,'Class',classDrop,'Train',retrain,'OpenExport',openExport,'Status',status,'Evidence',evidenceButton));
 function loadImage(path)
  I=fx_read(path);currentPath=string(path);result=[];imshow(I,'Parent',axes1(1));title(axes1(1),titles{1});
  for a=2:3,cla(axes1(a));title(axes1(a),titles{a});end
  for a=1:6,cla(ga(a));title(ga(a),'');end
  scoreTable.Data=cell(0,3);runButton.Enable='on';export.Enable='off';prediction.Text='图片已载入';
  [~,n,e]=fileparts(path);status.Text=[n e ' · 点击识别并检索'];tabs.SelectedTab=tab1;
 end
 function loadSample()
  ids=find(manifest.Label==classDrop.Value & manifest.Split=="test");sampleIndex=sampleIndex+1;
  loadImage(fullfile(c.root,manifest.Path(ids(mod(sampleIndex-1,numel(ids))+1))));
 end
 function choose()
  [n,p]=uigetfile({'*.jpg;*.jpeg;*.png;*.bmp;*.tif','图片文件'});if isequal(n,0),return;end
  try,loadImage(fullfile(p,n));catch ME,uialert(fig,ME.message,'无法打开');end
 end
 function r=recognize()
  r=[];if busy||strlength(currentPath)==0,return;end
  busy=true;setInputs('off');release=onCleanup(@finishBusy); %#ok<NASGU>
  runButton.Enable='off';export.Enable='off';result=[];status.Text='正在识别与检索……';drawnow;
  try
   result=fx_predict(model,currentPath);r=result;prediction.Text=char("识别结果："+r.name);
   message='102 类中的模型判断';if r.review,message='分数偏低，建议复核';end
   status.Text=sprintf('%s · 分数 %.1f%% · %.2f 秒 · 检索距离越小越相似',message,100*r.topScores(1),r.seconds);
   imshow(r.gray,'Parent',axes1(2));imshow(r.edge,'Parent',axes1(3));title(axes1(2),titles{2});title(axes1(3),titles{3});
   k=r.rank(1:5);scoreTable.Data=[cellstr(string((1:5)')),cellstr(classes.Display(k)),cellstr(compose('%.1f%%',100*r.topScores(1:5)'))];
   for a=1:6
    imshow(fx_read(fullfile(c.root,r.neighbors.Path(a))),'Parent',ga(a));
    title(ga(a),{char(classes.Display(r.neighbors.Label(a))),sprintf('距离 %.3f',r.distances(a))},'Interpreter','none','FontSize',9);
   end
   export.Enable='on';
  catch ME,prediction.Text='识别未完成';status.Text=ME.message;uialert(fig,ME.message,'识别失败');end
  runButton.Enable='on';drawnow;
 end
 function folder=saveResult(out)
  folder='';if isempty(result),return;end
  if nargin<1,out=fullfile(c.root,'exports');end
  try
   folder=fx_export(result,model,out);lastExport=string(folder);openExport.Enable='on';
   status.Text='结果已导出，可点击左侧“打开导出目录”。';status.Tooltip=folder;
   exportapp(fig,fullfile(folder,'interface.png'));
  catch ME,status.Text=['导出失败：' ME.message];uialert(fig,ME.message,'导出失败');end
 end
 function batch()
  if busy,return;end
  f=uigetdir(c.root,'选择批量识别图片文件夹');if isequal(f,0),return;end
  busy=true;setInputs('off');release=onCleanup(@finishBusy); %#ok<NASGU>
  dlg=uiprogressdlg(fig,'Title','批量识别','Message','准备图片','Cancelable','on','Value',0);
  closeProgress=onCleanup(@()closeBatchProgress(dlg)); %#ok<NASGU>
  status.Text='批量识别中，请等待完成……';drawnow;
  try
   out=fullfile(c.root,'exports',['batch_' char(datetime('now','Format','yyyyMMdd_HHmmss')) '.csv']);
   [t,completed]=batch_predict(f,out,@(done,total)batchProgress(dlg,done,total));failed=sum(~cellfun(@isempty,t.Error));
   action='已完成';if ~completed,action='已取消，保留已处理结果';end
   status.Text=sprintf('%s：成功 %d，失败 %d。结果位于 exports。',action,height(t)-failed,failed);
   lastExport=string(fullfile(c.root,'exports'));openExport.Enable='on';
  catch ME,status.Text=['批量失败：' ME.message];uialert(fig,ME.message,'批量失败');end
 end
 function keepGoing=batchProgress(dlg,done,total)
  if ~isvalid(dlg),keepGoing=false;return;end
  dlg.Value=done/max(total,1);dlg.Message=sprintf('已处理 %d / %d 张；可取消并保存已完成结果。',done,total);drawnow;
  keepGoing=~dlg.CancelRequested;
 end
 function closeBatchProgress(dlg),if isvalid(dlg),close(dlg);end,end
 function exportEvidence()
  evidenceButton.Enable='off';evidenceStatus.Text='正在复算测试指标……';drawnow;
  try
   coursework_summary();evidenceStatus.Text='复核通过，摘要已保存至 results/coursework_summary.json。';
  catch ME,evidenceStatus.Text=['复核失败：' ME.message];end
  evidenceButton.Enable='on';
 end
 function trainAgain()
  answer=uiconfirm(fig,'日常识别和答辩无需重训。重训会创建新模型版本，是否继续？','重新训练','Options',{'取消','开始训练'},'DefaultOption',1,'CancelOption',1);
  if ~strcmp(answer,'开始训练'),return;end
  retrain.Enable='off';dlg=uiprogressdlg(fig,'Title','训练模型','Message','请查看 MATLAB 命令窗口中的进度。','Indeterminate','on');drawnow;
  try,train_project(false);close(dlg);uialert(fig,'训练完成，请重新启动界面加载新模型。','训练完成');
  catch ME,close(dlg);uialert(fig,ME.message,'训练未完成');end
  retrain.Enable='on';
 end
 function changeChart()
  values={'training_curves.png','learning_curve.png','comparison.png','confusion.png','calibration.png'};
  idx=find(strcmp(selector.Items,selector.Value),1);imshow(imread(fullfile(runFolder,values{idx})),'Parent',chart);
 end
 function showPlot(name),figure('Name','真实训练记录','Color','w');imshow(imread(fullfile(runFolder,name)));end
 function loadError()
  ids=find(~preds.Correct);if isempty(ids),uialert(fig,'本次测试未发现误判。','提示');return;end
  sampleIndex=sampleIndex+1;i=ids(mod(sampleIndex-1,numel(ids))+1);loadImage(fullfile(c.root,preds.Path(i)));recognize();
  if isempty(result),return;end
  status.Text=char("真实标签："+classes.Display(preds.Label(i))+"；预测："+result.name+"。这是未参与训练的测试图片。");
 end
 function resetSample(),sampleIndex=0;end
 function setInputs(value)
  sample.Enable=value;chooseButton.Enable=value;classDrop.Enable=value;batchButton.Enable=value;retrain.Enable=value;runButton.Enable=value;
 end
 function finishBusy()
  busy=false;if ~isvalid(fig),return;end;setInputs('on');if strlength(currentPath)==0,runButton.Enable='off';end
 end
 function openOutput()
  if strlength(lastExport)==0||~isfolder(lastExport),status.Text='请先识别图片并导出结果。';return;end
  if ispc,winopen(char(lastExport));else,open(char(lastExport));end
 end
 function r=getResult(),r=result;end
 function selectTab(i),all=[tab1 tab2 tab3 tab4];tabs.SelectedTab=all(i);drawnow;end
end
