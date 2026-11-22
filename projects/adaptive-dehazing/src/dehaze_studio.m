function fig=dehaze_studio(visible)
%DEHAZE_STUDIO Classroom workbench for reproducible haze restoration.
if nargin<1,visible='on';end
root=fileparts(fileparts(mfilename('fullpath')));data=fullfile(root,'02_数据集','NH-HAZE_640');
I=[];reference=[];R=[];source='';busy=false;current=1;
fig=uifigure('Name','区域自适应去雾与复原评估','Position',[70 60 1320 850], ...
    'Color',[.96 .97 .98],'Visible',visible,'CloseRequestFcn',@closeApp);
grid=uigridlayout(fig,[6 1]);grid.RowHeight={44,42,48,'1x',88,24};grid.Padding=[16 12 16 12];
uilabel(grid,'Text','区域自适应去雾与复原评估','FontSize',25,'FontWeight','bold','FontColor',[.08 .19 .29]);
bar=uigridlayout(grid,[1 8]);bar.ColumnWidth={100,100,180,90,100,100,100,'1x'};bar.Padding=[0 0 0 0];
open=uibutton(bar,'Text','导入图片','ButtonPushedFcn',@chooseFile);
refButton=uibutton(bar,'Text','导入参考图','ButtonPushedFcn',@chooseReference);
sample=uidropdown(bar,'Items',arrayfun(@(x)sprintf('NH-HAZE %02d',x),1:55,'UniformOutput',false),'ValueChangedFcn',@sampleChanged);
loadBtn=uibutton(bar,'Text','载入案例','ButtonPushedFcn',@sampleChanged);
runBtn=uibutton(bar,'Text','开始去雾','ButtonPushedFcn',@process,'Enable','off','BackgroundColor',[.08 .35 .50],'FontColor','white');
saveBtn=uibutton(bar,'Text','导出结果','ButtonPushedFcn',@chooseExport,'Enable','off');
batchBtn=uibutton(bar,'Text','批量处理','ButtonPushedFcn',@batch);
view=uidropdown(bar,'Items',{'新版结果','主阶段透射率','残余阶段透射率','天空置信度','残余校正强度','反演裁剪风险'},'ValueChangedFcn',@redraw);
controls=uigridlayout(grid,[1 10]);controls.Padding=[0 0 0 0];controls.ColumnWidth={95,85,105,105,85,105,80,85,100,'1x'};
uilabel(controls,'Text','残余校正强度');strength=uieditfield(controls,'numeric','Limits',[0 1],'Value',.65,'ValueDisplayFormat','%.2f','ValueChangedFcn',@invalidate);
sky=uicheckbox(controls,'Text','天空保护','Value',true,'ValueChangedFcn',@invalidate);
guard=uicheckbox(controls,'Text','保守处理','Value',true,'ValueChangedFcn',@invalidate);
uilabel(controls,'Text','模拟雾强度');beta=uieditfield(controls,'numeric','Limits',[0 3],'Value',1.0);
uilabel(controls,'Text','随机种子');seed=uieditfield(controls,'numeric','Limits',[0 99999999],'RoundFractionalValues','on','Value',20261021,'ValueDisplayFormat','%.0f');
fogBtn=uibutton(controls,'Text','参考图加雾','ButtonPushedFcn',@simulate);
uilabel(controls,'Text','模拟深度场不代表真实距离','FontColor',[.37 .40 .44]);
panels=uigridlayout(grid,[2 2]);panels.Padding=[0 0 0 0];axesList=gobjects(1,4);
for k=1:4,axesList(k)=uiaxes(panels);axesList(k).XTick=[];axesList(k).YTick=[];end
details=uitextarea(grid,'Editable','off','FontSize',13,'Value',{'载入 55 组官方配对案例，或导入自己的图片。'; ...
    '参考图仅用于评价，不会传入去雾算法。图片及参数变化后，旧结果立即失效。'; ...
    '真实照片无参考图时不显示 PSNR/SSIM。'});
status=uilabel(grid,'Text','就绪。需 MATLAB 与 Image Processing Toolbox。');
setappdata(fig,'DehazeV2API',struct('load',@loadFile,'loadSample',@loadSample,'process',@process, ...
 'export',@exportTo,'simulate',@simulate,'state',@state,'strength',strength,'view',view));
redraw();
    function s=state
        s=struct('hasInput',~isempty(I),'hasReference',~isempty(reference),'hasResult',~isempty(R),'source',source,'busy',busy);
    end
    function invalidate(varargin)
        R=[];saveBtn.Enable='off';runBtn.Enable=matlab.lang.OnOffSwitchState(~isempty(I)&&~busy);redraw();
        status.Text='输入或参数已变化，请重新计算。';
    end
    function loadFile(file,ref)
        if busy,return;end
        I=[];reference=[];source='';invalidate();
        I=dehaze_read_image(file);source=char(file);
        if nargin>1 && ~isempty(ref)
            reference=dehaze_read_image(ref);assert(isequal(size(I),size(reference)),'Dehaze:ReferenceSize','参考图尺寸不符');
        end
        invalidate();status.Text=['已载入 ' source];
    end
    function loadSample(id)
        current=id;sample.Value=sprintf('NH-HAZE %02d',id);
        loadFile(fullfile(data,sprintf('%02d_hazy.png',id)),fullfile(data,sprintf('%02d_GT.png',id)));
    end
    function sampleChanged(varargin)
        try,loadSample(sscanf(sample.Value,'NH-HAZE %d'));catch err,uialert(fig,err.message,'案例读取失败');end
    end
    function chooseFile(varargin)
        [f,p]=uigetfile({'*.png;*.jpg;*.jpeg;*.bmp;*.tif','图像'});if isequal(f,0),return;end
        try,loadFile(fullfile(p,f));catch err,uialert(fig,err.message,'读取失败');end
    end
    function chooseReference(varargin)
        if isempty(I),uialert(fig,'请先载入输入图像。','尚无输入');return;end
        [f,p]=uigetfile({'*.png;*.jpg;*.jpeg;*.bmp;*.tif','参考图'});if isequal(f,0),return;end
        try
            candidate=dehaze_read_image(fullfile(p,f));
            assert(isequal(size(candidate),size(I)),'Dehaze:ReferenceSize','参考图须与输入同尺寸且配准，不能仅因尺寸相同就认作真值。');
            reference=candidate;invalidate();
        catch err,uialert(fig,err.message,'参考图不可用');end
    end
    function setBusy(b)
        busy=b;
        for control=[open refButton loadBtn runBtn saveBtn batchBtn fogBtn],control.Enable=matlab.lang.OnOffSwitchState(~b);end
        for control={sample,strength,sky,guard,beta,seed},control{1}.Enable=matlab.lang.OnOffSwitchState(~b);end
        runBtn.Enable=matlab.lang.OnOffSwitchState(~b&&~isempty(I));saveBtn.Enable=matlab.lang.OnOffSwitchState(~b&&~isempty(R));
    end
    function process(varargin)
        if busy||isempty(I),return;end
        R=[];setBusy(true);cleanup=onCleanup(@()setBusy(false)); %#ok<NASGU>
        status.Text='计算中…';drawnow;timer=tic;
        R=dehaze_v2(I,struct('strength',strength.Value,'skyProtection',.55*sky.Value,'guard',guard.Value));
        elapsed=toc(timer);view.Value='新版结果';redraw();
        lines={sprintf('耗时 %.2f 秒；整体处理系数 %.3f；输出与输入等尺寸。',elapsed,R.inputGate);R.warning};
        if ~isempty(reference)
            a=paired_quality(I,reference);b=paired_quality(R.baseline,reference);c=paired_quality(R.final,reference);
            lines{end+1}=sprintf('PSNR 输入/旧版/新版：%.2f / %.2f / %.2f dB；SSIM：%.4f / %.4f / %.4f',a.psnr,b.psnr,c.psnr,a.ssim,b.ssim,c.ssim);
        else,lines{end+1}='未提供配准清晰参考图，不计算 PSNR 与 SSIM。';end
        details.Value=lines;status.Text=R.status;
    end
    function simulate(varargin)
        if busy,return;end
        if isempty(reference),error('Dehaze:Reference','请先载入配对案例或提供清晰参考图。');end
        I=synthesize_haze(reference,beta.Value,seed.Value,'nonuniform');source=sprintf('合成雾 beta %.2f seed %d',beta.Value,seed.Value);
        invalidate();status.Text=['已生成 ' source '；清晰参考图未传入复原算法。'];
    end
    function redraw(varargin)
        labels={'输入雾图','新版去雾结果','原版 V1 对照','清晰参考图 仅供评价'};
        imgs={I,[],[],reference};if ~isempty(R),imgs{2}=R.final;imgs{3}=R.baseline;end
        keys={'final','mainTransmission','transmission','skyConfidence','strengthMap','clipRisk'};
        selected=find(strcmp(view.Items,view.Value),1);
        if ~isempty(R),imgs{2}=R.(keys{selected});labels{2}=view.Value;end
        for j=1:4
            ax=axesList(j);cla(ax);colorbar(ax,'off');
            if ~isempty(imgs{j})
                if j==2&&selected>1,imagesc(ax,imgs{j},[0 1]);axis(ax,'image');colorbar(ax);else,imshow(imgs{j},'Parent',ax);end
            end
            title(ax,labels{j},'Interpreter','none');ax.XTick=[];ax.YTick=[];
        end
    end
    function folder=exportTo(parent)
        if isempty(R),error('Dehaze:NoResult','请先处理当前图像。');end
        if ~isfolder(parent),mkdir(parent);end
        folder=tempname(parent);mkdir(folder);
        for key={'input','final','baseline','mainTransmission','transmission','skyConfidence','strengthMap'}
            imwrite(R.(key{1}),fullfile(folder,[key{1} '.png']));
        end
        if ~isempty(reference),imwrite(reference,fullfile(folder,'reference.png'));end
        meta=struct('source',source,'options',R.options,'inputGate',R.inputGate,'warning',R.warning,'matlab',version);
        fid=fopen(fullfile(folder,'parameters.json'),'w','n','UTF-8');fprintf(fid,'%s',jsonencode(meta,'PrettyPrint',true));fclose(fid);
        status.Text=['已导出到 ' folder];
    end
    function chooseExport(varargin)
        p=uigetdir(root,'选择导出父目录');if isequal(p,0),return;end
        try,exportTo(p);catch err,uialert(fig,err.message,'导出失败');end
    end
    function batch(varargin)
        p=uigetdir(root,'选择待处理图片文件夹');if isequal(p,0),return;end
        target=uigetdir(root,'选择输出父目录');if isequal(target,0),return;end
        files=dir(p);files=files(~[files.isdir]);ok=cellfun(@(n)~isempty(regexpi(n,'\.(jpg|jpeg|png|bmp|tif|tiff)$','once')),{files.name});files=files(ok);
        folder=tempname(target);mkdir(folder);setBusy(true);cleanup=onCleanup(@()setBusy(false)); %#ok<NASGU>
        dialog=uiprogressdlg(fig,'Title','批量去雾','Cancelable','on');dialogCleanup=onCleanup(@()delete(dialog)); %#ok<NASGU>
        rows={};
        for k=1:numel(files)
            drawnow;if dialog.CancelRequested,break;end
            dialog.Value=(k-1)/max(1,numel(files));dialog.Message=files(k).name;
            try
                input=dehaze_read_image(fullfile(p,files(k).name));timer=tic;
                result=dehaze_v2(input,struct('strength',strength.Value,'skyProtection',.55*sky.Value,'guard',guard.Value));
                imwrite(result.final,fullfile(folder,[files(k).name '_V2.png']));rows(end+1,:)={files(k).name,'OK',toc(timer)}; %#ok<AGROW>
            catch err,rows(end+1,:)={files(k).name,err.message,NaN};end %#ok<AGROW>
        end
        if ~isempty(rows),writetable(cell2table(rows,'VariableNames',{'file','status','seconds'}),fullfile(folder,'batch_log.csv'));end
        status.Text=sprintf('批量任务已结束，共记录 %d 个文件：%s',size(rows,1),folder);
    end
    function closeApp(varargin)
        if busy,uialert(fig,'处理进行中，请等待或取消批量任务。','正在处理');else,delete(fig);end
    end
end
