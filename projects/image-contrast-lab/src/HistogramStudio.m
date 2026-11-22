function fig=HistogramStudio
%HISTOGRAMSTUDIO MATLAB原生交互界面。run_project_checks会调用同一套回调。
root=fileparts(mfilename('fullpath'));cases=jsondecode(fileread(fullfile(root,'..','examples','cases.json')));
fig=uifigure('Name','明度实验室 | 直方图均衡化与对比度增强','Position',[40 40 1420 900],...
    'Color',[.96 .97 .95]);
grid=uigridlayout(fig,[4 2],'RowHeight',{66,75,'1x',225},'ColumnWidth',{'1x','1x'},'Padding',[18 12 18 12]);
header=uipanel(grid,'BorderType','none','BackgroundColor',[.96 .97 .95]);header.Layout.Column=[1 2];
hg=uigridlayout(header,[1 2],'ColumnWidth',{'1x',420});
uilabel(hg,'Text','明度实验室  /  MATLAB 图像增强','FontSize',24,'FontWeight','bold','FontColor',[.12 .25 .22]);
uilabel(hg,'Text','选案例 → 一键对比 → 导出结果','HorizontalAlignment','right','FontSize',16);
controls=uipanel(grid,'BorderType','none');controls.Layout.Row=2;controls.Layout.Column=[1 2];
cg=uigridlayout(controls,[2 7],'RowHeight',{22,30},'ColumnWidth',{260,110,110,110,100,110,'1x'});
labels={'内置案例','导入自己的照片','局部增强限幅','融合强度','保边平滑','运行四图对比','结果导出'};
for j=1:7,l=uilabel(cg,'Text',labels{j},'FontColor',[.35 .42 .39]);l.Layout.Row=1;l.Layout.Column=j;end
caseBox=uidropdown(cg,'Items',{cases.name},'ItemsData',1:numel(cases),'Value',1);place(caseBox,2,1);
importButton=uibutton(cg,'Text','导入图片');place(importButton,2,2);
clipBox=uieditfield(cg,'numeric','Limits',[.001 .1],'Value',.01);place(clipBox,2,3);
strengthBox=uieditfield(cg,'numeric','Limits',[0 1],'Value',.75);place(strengthBox,2,4);
denoiseBox=uicheckbox(cg,'Text','开启','Value',true);place(denoiseBox,2,5);
runButton=uibutton(cg,'Text','一键对比','BackgroundColor',[.15 .40 .31],'FontColor','w');place(runButton,2,6);
saveButton=uibutton(cg,'Text','导出图片与指标','Enable','off');place(saveButton,2,7);
panel=uipanel(grid,'BorderType','none');panel.Layout.Row=3;panel.Layout.Column=[1 2];
plots=uigridlayout(panel,[1 4],'ColumnWidth',{'1x','1x','1x','1x'});
ax=gobjects(1,4);names={'原图','全局均衡 HE','局部均衡 CLAHE','自适应融合'};
for k=1:4
    ax(k)=uiaxes(plots);ax(k).Toolbar.Visible='off';ax(k).XTick=[];ax(k).YTick=[];
    title(ax(k),names{k},'FontSize',16,'FontWeight','bold');
end
histAx=uiaxes(grid);histAx.Layout.Row=4;histAx.Layout.Column=1;
infoPanel=uipanel(grid,'BorderType','none');infoPanel.Layout.Row=4;infoPanel.Layout.Column=2;
ig=uigridlayout(infoPanel,[3 1],'RowHeight',{'1x',32,36},'Padding',[5 0 5 0]);
metricTable=uitable(ig,'ColumnName',{'方法','亮度均值','标准差','信息熵','端点占比%'},'RowName',{});
status=uilabel(ig,'Text','就绪：请选择案例，再点击一键对比。','WordWrap','on');
tip=uilabel(ig,'Text','只增强 Lab 亮度通道。熵和标准差不是唯一质量标准；过曝丢失的细节无法恢复。','WordWrap','on','FontColor',[.36 .42 .39]);
current=[];last=[];label='';
caseBox.ValueChangedFcn=@(~,~)loadCase;
importButton.ButtonPushedFcn=@(~,~)importImage;
runButton.ButtonPushedFcn=@(~,~)runCompare;
saveButton.ButtonPushedFcn=@(~,~)saveDialog;
clipBox.ValueChangedFcn=@(~,~)invalidate;
strengthBox.ValueChangedFcn=@(~,~)invalidate;
denoiseBox.ValueChangedFcn=@(~,~)invalidate;
fig.UserData=struct('Case',caseBox,'Clip',clipBox,'Strength',strengthBox,'Denoise',denoiseBox,...
    'Run',runButton,'Save',saveButton,'Status',status,'LoadCase',@loadCase,'RunCompare',@runCompare,...
    'Export',@saveTo,'GetResult',@getResult,'SetImage',@setImage,'Invalidate',@invalidate);
loadCase;
    function loadCase
        c=cases(caseBox.Value);current=readProjectImage(fullfile(root,'..','examples',c.file));label=c.name;invalidate;
        status.Text=[c.name '：' c.note];
    end
    function setImage(I,name)
        current=I;label=name;invalidate;
    end
    function importImage
        [file,path]=uigetfile({'*.png;*.jpg;*.jpeg;*.bmp;*.tif;*.tiff','图像文件'});
        if isequal(file,0),return;end
        try,setImage(readProjectImage(fullfile(path,file)),file);
        catch err,uialert(fig,err.message,'导入失败');end
    end
    function invalidate
        last=[];saveButton.Enable='off';
        for k=1:4,cla(ax(k));title(ax(k),names{k},'FontSize',16);end
        if ~isempty(current),imshow(current,'Parent',ax(1));title(ax(1),names{1});end
        cla(histAx);metricTable.Data={};status.Text='图片或参数已更新，请重新运行对比。';
    end
    function runCompare
        if isempty(current),return;end
        setBusy(true);status.Text='正在计算四种结果…';drawnow;
        restore=onCleanup(@()setBusy(false));
        try
            last=enhanceImage(current,'ClipLimit',clipBox.Value,'Strength',strengthBox.Value,'Denoise',denoiseBox.Value);
            for k=1:4,imshow(last.Images{k},'Parent',ax(k));title(ax(k),names{k},'FontSize',16);end
            plot(histAx,0:255,last.Histograms,'LineWidth',1.1);xlim(histAx,[0 255]);
            title(histAx,'亮度直方图对比');xlabel(histAx,'亮度级');ylabel(histAx,'概率');
            legend(histAx,last.Names,'Location','northoutside','Orientation','horizontal','FontSize',9);
            metricTable.Data=[last.Names',num2cell(round(last.Metrics(:,1:4),4))];
            status.Text=sprintf('完成 %.2f 秒 | γ=%.2f | 融合权重=%.2f | 可导出',last.Seconds,last.Gamma,last.Alpha);
            saveButton.Enable='on';
        catch err
            last=[];saveButton.Enable='off';status.Text=['处理失败：' err.message];
            uialert(fig,err.message,'处理失败');
        end
        drawnow;
    end
    function value=getResult,value=last;end
    function setBusy(value)
        if value,state='off';else,state='on';end
        for control=[caseBox,importButton,clipBox,strengthBox,denoiseBox,runButton],control.Enable=state;end
        if value,saveButton.Enable='off';end
    end
    function saveTo(folder)
        assert(~isempty(last),'尚无有效结果，请先运行对比。');exportResults(last,folder,label);
    end
    function saveDialog
        folder=uigetdir(pwd,'选择结果保存目录');if isequal(folder,0),return;end
        folder=fullfile(folder,['增强结果_' datestr(now,'yyyymmdd_HHMMSS')]);
        try,saveTo(folder);status.Text=['已保存：' folder];catch err,uialert(fig,err.message,'导出失败');end
    end
end
function place(obj,row,column),obj.Layout.Row=row;obj.Layout.Column=column;end
