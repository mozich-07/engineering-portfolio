function fig = cartoon_app(root,visibility)
%CARTOON_APP 简单、离线的 MATLAB 图像处理工作台。
if nargin<2,visibility='on';end
bg=[.94 .96 .96];ink=[.13 .20 .22];teal=[.06 .39 .37];white=[1 1 1];
presets={'natural','comic','poster','sketch'};styleNames={'柔和卡通','清晰漫画','平涂海报','黑白线稿'};
samples=cartoon_samples(root);sizes=[640 1280 1920];
state=struct('Input',[],'Result',[],'Name','','Source',struct(),'Busy',false,'Cancel',false,'StyleResults',{{}});
screen=get(groot,'ScreenSize');windowSize=min([1380 830],screen(3:4)-[80 100]);
windowPosition=[max(1,(screen(3)-windowSize(1))/2) max(1,(screen(4)-windowSize(2))/2) windowSize];
fig=figure('Name','图像卡通化工作台 · 数字图像处理','NumberTitle','off', ...
    'Color',bg,'MenuBar','none','ToolBar','none','Position',windowPosition, ...
    'Visible',visibility,'Tag','CartoonV2','CloseRequestFcn',@requestClose);
uicontrol(fig,'Style','text','Units','normalized','Position',[.025 .928 .75 .05], ...
    'String','图像卡通化工作台','FontName','Microsoft YaHei','FontSize',22,'FontWeight','bold', ...
    'HorizontalAlignment','left','BackgroundColor',bg,'ForegroundColor',ink);
uicontrol(fig,'Style','text','Units','normalized','Position',[.027 .892 .90 .029], ...
    'String','数字图像处理  /  色彩增强 · 保边平滑 · 色块简化 · 轮廓合成', ...
    'FontName','Microsoft YaHei','FontSize',11,'HorizontalAlignment','left','BackgroundColor',bg,'ForegroundColor',[.30 .38 .40]);
panel=uipanel(fig,'Units','normalized','Position',[.02 .09 .235 .785],'BackgroundColor',white,'BorderType','none');
controls=gobjects(0);buttons=gobjects(0);advancedControls=gobjects(0);
label('01  选择照片',.938,13,true);
sampleNames=cell(1,numel(samples));
for k=1:numel(samples),sampleNames{k}=sprintf('%02d  %s / %s',k,samples(k).category,samples(k).label);end
sample=popup(sampleNames,.875,@chooseSample);controls(end+1)=sample;
buttons(end+1)=button('导入本地图片',.797,@importFile);
label('02  调整效果',.735,13,true);
style=popup(styleNames,.676,@styleChanged);controls(end+1)=style;
settings=uicontrol(panel,'Style','checkbox','Units','normalized','Position',[.07 .621 .86 .036], ...
    'String','参数设置（可选）','FontName','Microsoft YaHei','FontSize',10,'BackgroundColor',white,'Callback',@toggleSettings);
controls(end+1)=settings;
colors=field('色块数量  4–64','48',.558);
smooth=field('平滑强度  0–1','0.50',.497);
detail=field('轮廓细节  0–1','0.35',.436);
saturation=field('饱和度  0.5–1.5','1.06',.375);
advancedControls(end+1)=label('输出长边',.310,10,false);
resolution=uicontrol(panel,'Style','popupmenu','Units','normalized','Position',[.48 .314 .45 .045], ...
    'String',{'640 快速预览','1280 标准','1920 高清'},'Value',2,'FontSize',10,'FontName','Microsoft YaHei', ...
    'BackgroundColor',white,'Callback',@markDirty);controls(end+1)=resolution;advancedControls(end+1)=resolution;
set(advancedControls,'Visible','off');
styleHelp=uicontrol(panel,'Style','text','Units','normalized','Position',[.08 .32 .84 .27], ...
    'String','','FontName','Microsoft YaHei','FontSize',12,'BackgroundColor',white, ...
    'ForegroundColor',[.29 .36 .38],'HorizontalAlignment','left');
processBtn=button('开始处理',.234,@processImage);buttons(end+1)=processBtn;
set(processBtn,'BackgroundColor',teal,'ForegroundColor',white,'FontWeight','bold','Tag','ProcessButton');
saveBtn=button('导出当前结果',.150,@saveResult);buttons(end+1)=saveBtn;set(saveBtn,'Enable','off','Tag','SaveButton');
batchBtn=button('批量处理（可选）',.066,@batchDialog);buttons(end+1)=batchBtn;
tabs=uitabgroup(fig,'Units','normalized','Position',[.27 .09 .71 .785]);
resultTab=uitab(tabs,'Title','  原图与效果  ','BackgroundColor',white);
stepsTab=uitab(tabs,'Title','  处理过程  ','BackgroundColor',white);
stylesTab=uitab(tabs,'Title','  四种风格  ','BackgroundColor',white);
infoTab=uitab(tabs,'Title','  照片与使用说明  ','BackgroundColor',white);
viewMode=uicontrol(resultTab,'Style','popupmenu','Units','normalized','Position',[.035 .918 .25 .045], ...
    'String',{'并排对比','滑动对比'},'FontName','Microsoft YaHei','FontSize',11,'BackgroundColor',white,'Callback',@renderResult);
controls(end+1)=viewMode;
wipe=uicontrol(resultTab,'Style','slider','Units','normalized','Position',[.34 .926 .40 .03], ...
    'Min',0,'Max',1,'Value',.5,'SliderStep',[.02 .10],'Visible','off','Callback',@renderResult);controls(end+1)=wipe;
wipeText=uicontrol(resultTab,'Style','text','Units','normalized','Position',[.76 .916 .21 .044], ...
    'String','左侧原图 / 右侧结果','FontSize',10,'FontName','Microsoft YaHei','BackgroundColor',white,'Visible','off');
axOriginal=axes(resultTab,'Units','normalized','Position',[.035 .20 .445 .64]);
axResult=axes(resultTab,'Units','normalized','Position',[.52 .20 .445 .64]);
axWipe=axes(resultTab,'Units','normalized','Position',[.04 .20 .92 .64],'Visible','off');
stats=uicontrol(resultTab,'Style','text','Units','normalized','Position',[.04 .045 .92 .10], ...
    'String','','FontName','Microsoft YaHei','FontSize',11,'HorizontalAlignment','left','BackgroundColor',white,'ForegroundColor',ink);
positions={[.04 .56 .43 .34],[.53 .56 .43 .34],[.04 .09 .43 .34],[.53 .09 .43 .34]};
stepAxes=gobjects(1,4);styleAxes=gobjects(1,4);
for k=1:4
    stepAxes(k)=axes(stepsTab,'Units','normalized','Position',positions{k});axis(stepAxes(k),'off');
    pos=positions{k};pos(2)=pos(2)-.03;pos(4)=pos(4)-.035;
    styleAxes(k)=axes(stylesTab,'Units','normalized','Position',pos);axis(styleAxes(k),'off');
end
compareBtn=uicontrol(stylesTab,'Style','pushbutton','Units','normalized','Position',[.035 .917 .30 .060], ...
    'String','生成四种风格对比','FontSize',11,'FontName','Microsoft YaHei','Callback',@compareStyles);buttons(end+1)=compareBtn;
uicontrol(stylesTab,'Style','text','Units','normalized','Position',[.37 .922 .58 .044], ...
    'String','使用各风格默认参数，长边 640 像素。','FontSize',10,'FontName','Microsoft YaHei', ...
    'BackgroundColor',white,'HorizontalAlignment','left');
infoText=uicontrol(infoTab,'Style','text','Units','normalized','Position',[.04 .05 .92 .90], ...
    'String','','FontName','Microsoft YaHei','FontSize',11,'HorizontalAlignment','left', ...
    'BackgroundColor',white,'ForegroundColor',ink);
status=uicontrol(fig,'Style','text','Units','normalized','Position',[.025 .022 .82 .04], ...
    'String','正在加载照片…','FontName','Microsoft YaHei','FontSize',11,'HorizontalAlignment','left', ...
    'BackgroundColor',bg,'ForegroundColor',ink,'Tag','StatusText');
cancelBtn=uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[.865 .020 .11 .042], ...
    'String','停止批处理','FontSize',10,'FontName','Microsoft YaHei','Visible','off','Callback',@cancelBatch);
api=struct('load',@loadImage,'process',@processImage,'preset',@setPreset,'export',@exportTo, ...
    'setValues',@setValues,'getState',@getState,'compare',@compareStyles,'batch',@batchTo, ...
    'tabs',tabs,'stepsTab',stepsTab,'stylesTab',stylesTab,'resultTab',resultTab, ...
    'colors',colors,'smooth',smooth,'detail',detail,'saturation',saturation,'resolution',resolution, ...
    'viewMode',viewMode,'wipe',wipe,'render',@renderResult,'saveButton',saveBtn,'status',status, ...
    'splitAxes',axWipe,'originalAxes',axOriginal,'outputAxes',axResult);
setappdata(fig,'CartoonAPI',api);
loadImage(fullfile(root,'samples',samples(1).file));setPreset(2);processImage();

    function h=label(text,y,size,bold)
        weight='normal';if bold,weight='bold';end
        h=uicontrol(panel,'Style','text','Units','normalized','Position',[.07 y .87 .048], ...
            'String',text,'FontName','Microsoft YaHei','FontSize',size,'FontWeight',weight, ...
            'BackgroundColor',white,'ForegroundColor',ink,'HorizontalAlignment','left');
    end
    function h=popup(text,y,callback)
        h=uicontrol(panel,'Style','popupmenu','Units','normalized','Position',[.07 y .86 .052], ...
            'String',text,'FontName','Microsoft YaHei','FontSize',11,'BackgroundColor',white,'Callback',callback);
    end
    function h=button(text,y,callback)
        h=uicontrol(panel,'Style','pushbutton','Units','normalized','Position',[.07 y .86 .065], ...
            'String',text,'FontName','Microsoft YaHei','FontSize',12,'Callback',callback);
    end
    function h=field(text,value,y)
        advancedControls(end+1)=label(text,y,10,false);
        h=uicontrol(panel,'Style','edit','Units','normalized','Position',[.68 y+.004 .25 .049], ...
            'String',value,'FontSize',11,'BackgroundColor',white,'Callback',@markDirty);
        controls(end+1)=h;advancedControls(end+1)=h;
    end
    function show(a,axisHandle,text)
        imshow(a,'Parent',axisHandle);title(axisHandle,text,'FontName','Microsoft YaHei','FontSize',12,'FontWeight','normal','Interpreter','none');
    end
    function loadImage(path)
        if state.Busy,error('Cartoon:Busy','请等待当前处理结束。');end
        [input,~]=read_image_safe(path); % Read before replacing the valid current state.
        state.Input=input;state.Result=[];state.StyleResults={};[~,name,ext]=fileparts(path);state.Name=[name ext];
        state.Source=struct('File',path);
        for j=1:numel(samples)
            if strcmpi(path,fullfile(root,'samples',samples(j).file)),state.Source=samples(j);set(sample,'Value',j);break;end
        end
        for j=1:4,cla(stepAxes(j));axis(stepAxes(j),'off');cla(styleAxes(j));axis(styleAxes(j),'off');end
        set(saveBtn,'Enable','off');set(status,'String','图片已加载。选择风格后点击“开始处理”。');
        set(stats,'String',sprintf('原始尺寸 %d × %d；尚未处理。',size(input,2),size(input,1)));
        renderResult();updateInfo();
    end
    function chooseSample(~,~)
        j=get(sample,'Value');
        try
            loadImage(fullfile(root,'samples',samples(j).file));setPreset(find(strcmp(presets,samples(j).recommended),1));processImage();
        catch err,set(status,'String',['加载失败：' err.message]);end
    end
    function importFile(~,~)
        [f,d]=uigetfile({'*.jpg;*.jpeg;*.png;*.bmp;*.tif;*.tiff','图片 JPG / PNG / BMP / TIFF'},'导入图片');
        if isequal(f,0),return;end
        try,loadImage(fullfile(d,f));catch err,set(status,'String',['导入失败：' err.message]);end
    end
    function styleChanged(varargin)
        p=cartoon_defaults(presets{get(style,'Value')});
        set(colors,'String',num2str(p.Colors));set(smooth,'String',num2str(p.SmoothStrength));
        set(detail,'String',num2str(p.EdgeDetail));set(saturation,'String',num2str(p.Saturation));
        descriptions={{'颜色自然，轮廓较轻。';'适合人像、动物和山水。'}, ...
            {'色块鲜明，线条清晰。';'适合建筑、街景和静物。'}, ...
            {'减少颜色，突出大色块。';'适合彩色墙面与简单构图。'}, ...
            {'去掉色彩，只保留线条。';'适合观察图像中的轮廓。'}};
        set(styleHelp,'String',[descriptions{get(style,'Value')};{'';'选好风格，点击“开始处理”。';'默认参数即可使用。';'';'12 张新照片，离线可用。'}]);
        markDirty();setEnabled();
    end
    function toggleSettings(varargin)
        if get(settings,'Value'),set(advancedControls,'Visible','on');set(styleHelp,'Visible','off');
        else,set(advancedControls,'Visible','off');set(styleHelp,'Visible','on');end
    end
    function setPreset(k)
        validateattributes(k,{'numeric'},{'scalar','integer','>=',1,'<=',4});set(style,'Value',k);styleChanged();
    end
    function setValues(values)
        if isfield(values,'Colors'),set(colors,'String',num2str(values.Colors));end
        if isfield(values,'SmoothStrength'),set(smooth,'String',num2str(values.SmoothStrength));end
        if isfield(values,'EdgeDetail'),set(detail,'String',num2str(values.EdgeDetail));end
        if isfield(values,'Saturation'),set(saturation,'String',num2str(values.Saturation));end
        if isfield(values,'MaxDimension')
            j=find(sizes==values.MaxDimension,1);if isempty(j),error('Cartoon:Size','界面支持 640、1280、1920。');end
            set(resolution,'Value',j);
        end
        markDirty();
    end
    function markDirty(varargin)
        state.Result=[];set(saveBtn,'Enable','off');
        set(status,'String','参数已更改，请重新处理；导出将在处理完成后启用。');
        cla(axResult);cla(axWipe);title(axResult,'等待按当前参数重新处理','FontName','Microsoft YaHei','FontSize',11);axis(axResult,'off');
        for j=1:4,cla(stepAxes(j));axis(stepAxes(j),'off');end
        set(stats,'String','当前参数还未生成结果。');renderResult();
    end
    function p=readParams()
        p=cartoon_defaults(presets{get(style,'Value')});
        p.Colors=str2double(get(colors,'String'));p.SmoothStrength=str2double(get(smooth,'String'));
        p.EdgeDetail=str2double(get(detail,'String'));p.Saturation=str2double(get(saturation,'String'));
        p.MaxDimension=sizes(get(resolution,'Value'));
        values=[p.Colors,p.SmoothStrength,p.EdgeDetail,p.Saturation];
        if any(~isfinite(values)) || p.Colors<4 || p.Colors>64 || mod(p.Colors,1)~=0 || ...
                p.SmoothStrength<0 || p.SmoothStrength>1 || p.EdgeDetail<0 || p.EdgeDetail>1 || p.Saturation<.5 || p.Saturation>1.5
            error('Cartoon:Parameters','请检查参数：色数 4–64 的整数；平滑和细节 0–1；饱和度 0.5–1.5。');
        end
    end
    function ok=processImage(varargin)
        ok=false;if state.Busy||isempty(state.Input),return;end
        lock();cleanup=onCleanup(@unlock); %#ok<NASGU>
        try
            p=readParams();state.Result=[];r=cartoon_process(state.Input,p,@progress);
            state.Result=r;renderResult();
            show(r.Smoothed,stepAxes(1),'1  Lab 保边平滑');show(r.Quantized,stepAxes(2),'2  色块简化');
            show(r.Outline,stepAxes(3),'3  轮廓提取与柔化');show(r.Result,stepAxes(4),'4  最终合成');
            set(stats,'String',sprintf('输出 %d × %d  |  量化色板 %d 色  |  轮廓占比 %.1f%%  |  %.2f 秒\n最终图包含色彩混合和柔化轮廓；统计量用于解释处理过程。', ...
                size(r.Result,2),size(r.Result,1),r.PaletteSize,100*r.EdgeRatio,r.Elapsed));
            set(status,'String','处理完成。可查看分步、滑动对比，或导出当前结果。');ok=true;updateInfo();
        catch err
            state.Result=[];set(status,'String',['处理失败：' err.message]);
        end
    end
    function renderResult(varargin)
        if isempty(state.Input),return;end
        split=get(viewMode,'Value')==2 && ~isempty(state.Result);
        if split
            cla(axOriginal);cla(axResult);title(axOriginal,'');title(axResult,'');axis(axOriginal,'off');axis(axResult,'off');
            r=state.Result;mix=r.Result;cut=round(size(mix,2)*get(wipe,'Value'));
            if cut>0,mix(:,1:cut,:)=r.Original(:,1:cut,:);end
            if cut>0 && cut<size(mix,2),mix(:,cut,:)=255;end
            show(mix,axWipe,'滑动对比');set([wipe wipeText],'Visible','on');
        else
            cla(axWipe);title(axWipe,'');axis(axWipe,'off');set([wipe wipeText],'Visible','off');
            displayName=state.Name;
            if isfield(state.Source,'label'),displayName=state.Source.label;end
            show(state.Input,axOriginal,['原图 · ' displayName]);
            if ~isempty(state.Result),show(state.Result.Result,axResult,styleNames{get(style,'Value')});
            else,cla(axResult);axis(axResult,'off');title(axResult,'等待处理','FontName','Microsoft YaHei','FontSize',12);end
        end
    end
    function results=compareStyles(varargin)
        results={};if state.Busy||isempty(state.Input),return;end
        lock();cleanup=onCleanup(@unlock); %#ok<NASGU>
        tabs.SelectedTab=stylesTab;
        try
            for j=1:4
                progress(sprintf('风格对比 %d/4：%s',j,styleNames{j}));p=cartoon_defaults(presets{j});p.MaxDimension=640;
                results{j}=cartoon_process(state.Input,p);show(results{j}.Result,styleAxes(j),styleNames{j}); %#ok<AGROW>
            end
            state.StyleResults=results;set(status,'String','风格对比完成。左侧选择风格可生成标准或高清结果。');
        catch err,set(status,'String',['风格对比失败：' err.message]);end
    end
    function folder=exportTo(parent)
        if isempty(state.Result),error('Cartoon:NoResult','请先按当前参数处理图片。');end
        folder=export_result(state.Result,parent,state.Source);[~,name]=fileparts(folder);
        set(status,'String',['已保存到所选文件夹中的 ' name '。']);
    end
    function saveResult(~,~)
        parent=uigetdir(fullfile(root,'exports'),'选择导出位置');if isequal(parent,0),return;end
        try,exportTo(parent);catch err,set(status,'String',err.message);end
    end
    function report=batchTo(paths,parent)
        if state.Busy,error('Cartoon:Busy','请等待当前处理结束。');end
        p=readParams();lock();state.Cancel=false;set(cancelBtn,'Visible','on');cleanup=onCleanup(@unlock); %#ok<NASGU>
        metadata=cell(size(paths));
        for i=1:numel(paths)
            for j=1:numel(samples)
                if strcmpi(paths{i},fullfile(root,'samples',samples(j).file)),metadata{i}=samples(j);break;end
            end
        end
        report=cartoon_batch(paths,parent,p,@batchProgress,@()state.Cancel,metadata);
        set(status,'String',sprintf('批处理结束：成功 %d，失败 %d，未处理 %d。%s',report.Passed,report.Failed,report.Requested-report.Processed,report.Folder));
    end
    function batchDialog(~,~)
        inputFolder=uigetdir(fullfile(root,'samples'),'选择图片文件夹（仅处理本层图片）');if isequal(inputFolder,0),return;end
        outputFolder=uigetdir(fullfile(root,'exports'),'选择批量导出位置');if isequal(outputFolder,0),return;end
        files=dir(inputFolder);paths={};
        for i=1:numel(files)
            [~,~,ext]=fileparts(files(i).name);
            if ~files(i).isdir && ismember(lower(ext),{'.jpg','.jpeg','.png','.bmp','.tif','.tiff'}),paths{end+1}=fullfile(inputFolder,files(i).name);end %#ok<AGROW>
        end
        try,batchTo(paths,outputFolder);catch err,set(status,'String',['批处理失败：' err.message]);end
    end
    function batchProgress(i,n,file)
        [~,name,ext]=fileparts(file);progress(sprintf('批处理 %d/%d：%s%s；可在本张结束后停止。',i,n,name,ext));
    end
    function cancelBatch(varargin),state.Cancel=true;set(status,'String','已请求停止，将在当前图片完成后结束。');end
    function progress(message),set(status,'String',message);drawnow;end
    function lock(),state.Busy=true;set([buttons controls],'Enable','off');drawnow;end
    function unlock()
        if ~isgraphics(fig),return;end
        state.Busy=false;set(cancelBtn,'Visible','off');setEnabled();
    end
    function setEnabled()
        set([buttons controls],'Enable','on');
        if get(style,'Value')==4,set([colors saturation],'Enable','off');end
        if isempty(state.Result),set(saveBtn,'Enable','off');end
    end
    function updateInfo()
        source={'本地导入照片';'请根据原图的授权条件使用与分享处理结果。'};
        if isfield(state.Source,'author')
            source={['照片：' state.Source.label ' / ' state.Source.category];['作者：' state.Source.author]; ...
                ['许可：' state.Source.license];['来源：' state.Source.source_page]};
        end
        text=[source;{'';'操作顺序';'1. 选择样片或导入自己的图片。';'2. 选风格，按需要改色数、平滑、轮廓细节和饱和度。'; ...
            '3. 点击“开始处理”，再查看分步、滑动对比或导出。';'';'参数怎么理解'; ...
            '色数越少，色块越明显；平滑越大，细小纹理越少。';'轮廓细节越大，保留的线条越多。'; ...
            '饱和度 1 表示不调整；黑白线稿不使用颜色参数。';'输出保持比例，小图不会放大。';''; ...
            '批处理与导出';'文件夹批处理只读取本层支持的图片，坏图会记录后跳过。'; ...
            '每次导出创建新目录，包含原图、过程图、结果和参数。'; ...
            '内置照片的署名与许可会随导出保存。';'';'适用范围'; ...
            '这是传统数字图像处理：强化色块和轮廓。';'低照度、细密毛发和复杂夜景需要适当调整参数。'; ...
            '支持 JPG / PNG / BMP / TIFF；透明图合成白底。';'多页 TIFF 仅处理第一页，超 4000 万像素请先缩小。'}];
        set(infoText,'String',text);
    end
    function s=getState(),s=state;end
    function requestClose(varargin)
        if state.Busy,state.Cancel=true;set(status,'String','正在完成当前图片，请稍候再关闭窗口。');else,delete(fig);end
    end
end
