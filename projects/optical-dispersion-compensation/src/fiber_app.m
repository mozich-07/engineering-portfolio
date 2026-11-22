function fig = fiber_app(mode)
% FIBER_APP Offline classroom demonstration. Basic MATLAB only.
if nargin<1, mode='interactive'; end
codeDir=fileparts(mfilename('fullpath')); addpath(codeDir); root=fileparts(codeDir);
c=fiber_config(); modelPath=fullfile(root,'results','trained_model.mat');
assert(exist(modelPath,'file')==2,'Run run_all first to create the model.');
q=load(modelPath); model=q.model; current=[]; currentExample=[];
fig=figure('Name','光纤色散与机器学习均衡实验','NumberTitle','off', ...
    'Color',[.96 .97 .99],'Position',[80 60 1220 790],'MenuBar','none','ToolBar','none');
if strcmp(mode,'smoke'), set(fig,'Visible','off'); end
uicontrol(fig,'Style','text','Units','normalized','Position',[.025 .92 .95 .06], ...
    'String','光纤色散补偿 · 岭回归监督学习','FontSize',22,'FontWeight','bold', ...
    'HorizontalAlignment','left','BackgroundColor',[.96 .97 .99]);
uicontrol(fig,'Style','text','Units','normalized','Position',[.025 .872 .12 .03],'String','链路长度 km','BackgroundColor',[.96 .97 .99]);
len=uicontrol(fig,'Style','popupmenu','Units','normalized','Position',[.145 .873 .08 .035],'String',{'40','80','120'},'Value',2,'Callback',@invalidate);
uicontrol(fig,'Style','text','Units','normalized','Position',[.24 .872 .1 .03],'String','Es/N0 dB','BackgroundColor',[.96 .97 .99]);
snr=uicontrol(fig,'Style','popupmenu','Units','normalized','Position',[.34 .873 .08 .035],'String',{'12','16','18','20','24'},'Value',3,'Callback',@invalidate);
btn=uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[.45 .864 .15 .05], ...
    'String','运行当前参数','FontSize',12,'Callback',@demo);
trainBtn=uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[.62 .864 .16 .05], ...
    'String','训练当前长度模型','FontSize',12,'Callback',@retrain);
exportBtn=uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[.80 .864 .16 .05], ...
    'String','导出本次结果','FontSize',12,'Callback',@exportCurrent,'Enable','off');
status=uicontrol(fig,'Style','text','Units','normalized','Position',[.025 .805 .95 .045], ...
    'String','就绪：已加载80 km预训练模型。改变长度可以观察模型失配。','FontSize',11, ...
    'HorizontalAlignment','left','BackgroundColor',[.96 .97 .99]);
axs=gobjects(1,4); positions=[.06 .47 .39 .28;.56 .47 .39 .28;.06 .115 .39 .28;.56 .115 .39 .28];
for k=1:4, axs(k)=axes(fig,'Position',positions(k,:)); end
footer=uicontrol(fig,'Style','text','Units','normalized','Position',[.025 .015 .95 .063], ...
    'String','数据为仿真数据；参数已归一化，未建模激光器、偏振、Kerr非线性。', ...
    'FontSize',11,'HorizontalAlignment','left','BackgroundColor',[.96 .97 .99]);
set(findall(fig,'-property','FontName'),'FontName','Microsoft YaHei');
setappdata(fig,'runDemo',@demo); setappdata(fig,'exportCurrent',@exportCurrent);
demo();
    function [L,S]=values()
        ls=get(len,'String'); ss=get(snr,'String'); L=str2double(ls{get(len,'Value')}); S=str2double(ss{get(snr,'Value')});
    end
    function invalidate(~,~)
        current=[]; currentExample=[]; set(exportBtn,'Enable','off');
        for a=axs, cla(a); end
        set(status,'String','参数已改变，请点击运行当前参数。');
        set(footer,'String','旧结果已清除。');
    end
    function busy(on)
        state='on'; if on, state='off'; end
        set([btn trainBtn len snr],'Enable',state); drawnow;
    end
    function demo(varargin)
        busy(true); cleanup=onCleanup(@()busy(false)); %#ok<NASGU>
        [L,S]=values();
        try
            blocks=make_blocks(c,4,S,L,900000,'demo');
            [current,~,currentExample]=evaluate_blocks(blocks,model,c);
            e=currentExample; zs={e.tx,e.rx,e.ml,e.oracle};
            names={'发送符号','色散后 未补偿','机器学习均衡后','真实参数补偿 参考'};
            for j=1:4
                plot(axs(j),real(zs{j}),imag(zs{j}),'.','MarkerSize',4); axis(axs(j),'equal');
                xlim(axs(j),[-2 2]); ylim(axs(j),[-2 2]); grid(axs(j),'on');
                title(axs(j),names{j}); xlabel(axs(j),'I'); ylabel(axs(j),'Q');
            end
            msg=sprintf('当前 %g km / %g dB；模型训练于 %g km，K=%d，lambda=%g。',L,S,model.lengthKm,model.K,model.lambda);
            if L~=model.lengthKm, msg=[msg ' 长度变化：模型可能失效，请比较或重新训练。']; end
            set(status,'String',msg);
            set(footer,'String',sprintf('BER：未补偿 %.5g   固定60 km %.5g   机器学习 %.5g   理想补偿 %.5g\n本次测试 %d bit；独立于训练，零误码不代表理论误码率为零。',current.BER,current.TotalBits(1)));
            set(exportBtn,'Enable','on');
            setappdata(fig,'summary',current); setappdata(fig,'example',e);
        catch err
            set(status,'String',['运行失败：' err.message]); rethrow(err);
        end
    end
    function retrain(varargin)
        busy(true); cleanup=onCleanup(@()busy(false)); %#ok<NASGU>
        [L,~]=values(); set(status,'String','正在生成独立训练和验证数据，并比较30组参数…'); drawnow;
        cfg=c; cfg.lengthKm=L;
        train=make_blocks(cfg,c.trainBlocks,c.trainSnr,L,610000,'demo_train');
        val=make_blocks(cfg,c.valBlocks,c.trainSnr,L,620000,'demo_validation');
        [model,search,curve]=train_equalizer(train,val,cfg); %#ok<ASGLU>
        exportDir=fullfile(root,'07_运行导出'); if ~exist(exportDir,'dir'),mkdir(exportDir);end
        save(fullfile(exportDir,sprintf('interactive_model_%dkm.mat',L)),'model','cfg','search','curve');
        demo();
    end
    function exportCurrent(varargin)
        if isempty(current),return;end
        exportDir=fullfile(root,'07_运行导出'); if ~exist(exportDir,'dir'),mkdir(exportDir);end
        stem=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
        writetable(current,fullfile(exportDir,[stem '_metrics.csv']));
        example=currentExample; save(fullfile(exportDir,[stem '_signals.mat']),'example','model','c');
        frame=getframe(fig); imwrite(frame.cdata,fullfile(exportDir,[stem '_figure.png']));
        set(status,'String',['已导出到：' exportDir]);
    end
end
