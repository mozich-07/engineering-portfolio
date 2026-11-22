classdef RestoreLabApp < handle
    % Chinese desktop UI; simulation and real-image states are separate.
    properties
        Figure; Mode; Kind; Strength; Angle; Noise; Amount
        Axes; MetricsTable; Status; SimulateButton; RestoreButton; ExportButton
        Config; Model; Source=[]; Reference=[]; Input=[]; Output=[]
        Example; Gallery
    end
    methods
        function app=RestoreLabApp(visibility)
            app.Config=setup_project(); app.Model=restorelab.load_model(app.Config);
            app.Figure=uifigure('Name','基于 MATLAB 的图像锐化与模糊复原设计','Position',[80 60 1320 850],'Visible',visibility);
            app.Figure.CloseRequestFcn=@(~,~)delete(app);
            g=uigridlayout(app.Figure,[3 2]); g.RowHeight={54,'1x',36}; g.ColumnWidth={280,'1x'}; g.Padding=[14 12 14 12];
            titleLabel=uilabel(g,'Text','图像锐化与模糊复原  |  机器学习实验室','FontSize',22,'FontWeight','bold','FontColor',[.09 .16 .28]);
            titleLabel.Layout.Row=1; titleLabel.Layout.Column=[1 2];
            panel=uipanel(g,'Title','操作与参数'); panel.Layout.Row=2; panel.Layout.Column=1;
            side=uigridlayout(panel,[22 1]); side.Scrollable='on'; side.Padding=[12 12 12 12];
            side.RowSpacing=5;
            side.RowHeight={22,34,38,32,38,22,32,22,32,22,32,22,32,22,32,40,42,38,42,38,60,'1x'};
            uilabel(side,'Text','1  选择工作模式','FontWeight','bold');
            app.Mode=uidropdown(side,'Items',{'模拟实验  导入清晰图','真实图片  导入模糊图'},'ItemsData',{'simulation','real'},'ValueChangedFcn',@(~,~)app.changeMode());
            uibutton(side,'Text','导入图像','ButtonPushedFcn',@(~,~)app.loadFile());
            app.Gallery=jsondecode(fileread(fullfile(app.Config.root,'演示素材与结果对比','素材清单.json')));
            app.Example=uidropdown(side,'Items',{app.Gallery.title},'ItemsData',{app.Gallery.id});
            uibutton(side,'Text','载入所选示例','ButtonPushedFcn',@(~,~)app.loadExample());
            uilabel(side,'Text','2  模糊类型与参数','FontWeight','bold');
            app.Kind=uidropdown(side,'Items',{'高斯模糊','运动模糊'},'ItemsData',{'gaussian','motion'},'ValueChangedFcn',@(~,~)app.kindChanged());
            uilabel(side,'Text','高斯 sigma 或运动长度 px');
            app.Strength=uieditfield(side,'numeric','Value',1.5,'Limits',[0.1 31],'ValueChangedFcn',@(~,~)app.parametersChanged());
            uilabel(side,'Text','运动角度 °  高斯模式忽略');
            app.Angle=uieditfield(side,'numeric','Value',0,'Limits',[-180 180],'ValueChangedFcn',@(~,~)app.parametersChanged());
            uilabel(side,'Text','噪声标准差  归一化到 0 至 1');
            app.Noise=uieditfield(side,'numeric','Value',0.015,'Limits',[0 0.1],'ValueChangedFcn',@(~,~)app.parametersChanged());
            uilabel(side,'Text','输出锐化强度  0 表示不额外锐化');
            app.Amount=uieditfield(side,'numeric','Value',app.Model.sharpAmount,'Limits',[0 1.5],'ValueChangedFcn',@(~,~)app.clearOutput());
            app.SimulateButton=uibutton(side,'Text','3  生成模糊图','ButtonPushedFcn',@(~,~)app.simulate());
            app.RestoreButton=uibutton(side,'Text','4  执行复原与学习修正','BackgroundColor',[.12 .36 .68],'FontColor',[1 1 1],'ButtonPushedFcn',@(~,~)app.restore());
            app.ExportButton=uibutton(side,'Text','5  导出图像 参数与指标','ButtonPushedFcn',@(~,~)app.export());
            uibutton(side,'Text','重新训练模型','ButtonPushedFcn',@(~,~)app.train());
            uibutton(side,'Text','打开使用手册','ButtonPushedFcn',@(~,~)app.help());
            uilabel(side,'Text',sprintf('模型：监督残差回归\n真实图的模糊参数需要估计。\n仅锐化不等于恢复丢失细节。'),'WordWrap','on','FontColor',[.3 .35 .4]);
            main=uigridlayout(g,[2 1]); main.Layout.Row=2; main.Layout.Column=2; main.RowHeight={'1x',170}; main.Padding=[0 0 0 0];
            views=uigridlayout(main,[2 3]); views.Padding=[0 0 0 0]; views.RowSpacing=8; views.ColumnSpacing=8;
            app.Axes=gobjects(1,6);
            for k=1:6
                app.Axes(k)=uiaxes(views); app.Axes(k).XTick=[]; app.Axes(k).YTick=[];
                app.Axes(k).Toolbar.Visible='off';
            end
            app.MetricsTable=uitable(main,'ColumnName',{'方法','PSNR dB','SSIM','RMSE','梯度能量','饱和比例'},'RowName',[],'ColumnWidth',{120,100,90,90,100,100});
            app.Status=uilabel(g,'Text','就绪：载入示例或导入图像开始。','FontColor',[.16 .25 .35]); app.Status.Layout.Row=3; app.Status.Layout.Column=[1 2];
            app.refresh();
        end
        function ingestImage(app,I)
            app.Source=I; app.Reference=[]; app.Input=[]; app.Output=[];
            if strcmp(app.Mode.Value,'simulation'), app.Reference=I; else, app.Input=I; end
            app.Status.Text=sprintf('已载入 %d × %d 图像；超过 2048 像素的输入会等比缩小。',size(I,2),size(I,1));
            app.refresh();
        end
        function loadFile(app)
            [name,folder]=uigetfile({'*.png;*.jpg;*.jpeg;*.bmp;*.tif;*.tiff','图像文件'});
            if isequal(name,0), return; end
            try, app.ingestImage(restorelab.read_image(fullfile(folder,name),2048));
            catch err, app.fail(err); end
        end
        function loadExample(app)
            item=app.Gallery(strcmp({app.Gallery.id},app.Example.Value));
            if strcmp(app.Mode.Value,'real')
                file=fullfile(app.Config.root,'演示素材与结果对比','02_模拟模糊输入',[item.id '_gaussian_15.png']);
                app.Kind.Value='gaussian'; app.Strength.Value=1.5; app.Angle.Value=0; app.Noise.Value=.015;
            else
                file=fullfile(app.Config.root,'演示素材与结果对比',item.file);
            end
            app.ingestImage(restorelab.read_image(file,640));
        end
        function changeMode(app)
            if ~isempty(app.Source), app.ingestImage(app.Source); else, app.refresh(); end
        end
        function kindChanged(app)
            if strcmp(app.Kind.Value,'motion'), app.Strength.Value=7; else, app.Strength.Value=1.5; end
            app.parametersChanged();
        end
        function parametersChanged(app)
            app.Output=[];
            if strcmp(app.Mode.Value,'simulation'), app.Input=[]; end
            app.Status.Text='参数已改变；模拟模式请重新生成模糊图，真实模式可重新复原。';
            app.refresh();
        end
        function clearOutput(app)
            app.Output=[]; app.refresh(); app.Status.Text='锐化强度已改变，请重新执行复原。';
        end
        function p=params(app)
            p=struct('kind',app.Kind.Value,'strength',app.Strength.Value,'angle',app.Angle.Value);
        end
        function simulate(app)
            try
                assert(~isempty(app.Reference),'RestoreLab:NoReference','先导入清晰图或载入示例。');
                app.Input=restorelab.degrade(app.Reference,app.params(),app.Noise.Value,app.Config.seed+900000);
                app.Output=[]; app.Status.Text='模拟完成：复原只接收模糊图和参数，清晰图仅用于评估。'; app.refresh();
            catch err, app.fail(err); end
        end
        function restore(app)
            try
                assert(~isempty(app.Input),'RestoreLab:NoInput','请先生成或导入模糊图。');
                app.RestoreButton.Enable='off'; app.Status.Text='正在复原并计算对照结果…'; drawnow;
                app.Output=restorelab.process(app.Input,app.params(),app.Noise.Value,app.Model,app.Amount.Value,app.Reference);
                if app.Output.hasReference
                    app.Status.Text=sprintf('完成，用时 %.2f 秒。PSNR/SSIM/RMSE 在裁去 12 像素边界后计算。',app.Output.seconds);
                else
                    app.Status.Text=sprintf('完成，用时 %.2f 秒。无清晰参考，PSNR/SSIM 不可计算；梯度能量不代表复原正确。',app.Output.seconds);
                end
                app.refresh();
            catch err, app.refresh(); app.fail(err); end
        end
        function refresh(app)
            titles={'清晰参考','输入模糊图','仅锐化对照','维纳复原','机器学习修正','最终输出'};
            images={app.Reference,app.Input,[],[],[],[]};
            if ~isempty(app.Output), images(3:6)={app.Output.sharpenOnly,app.Output.wiener,app.Output.learned,app.Output.final}; end
            for k=1:6
                ax=app.Axes(k); cla(ax,'reset');
                if isempty(images{k})
                    ax.XLim=[0 1]; ax.YLim=[0 1]; ax.XTick=[]; ax.YTick=[];
                    text(ax,.5,.5,'等待图像','HorizontalAlignment','center','Color',[.45 .5 .55]);
                else
                    imshow(images{k},'Parent',ax);
                    ax.XLim=[0.5 size(images{k},2)+0.5];
                    ax.YLim=[0.5 size(images{k},1)+0.5];
                    ax.YDir='reverse'; ax.DataAspectRatio=[1 1 1];
                end
                ax.XTick=[]; ax.YTick=[]; ax.Toolbar.Visible='off';
                title(ax,titles{k},'FontSize',13,'FontWeight','bold');
            end
            app.Angle.Enable=matlab.lang.OnOffSwitchState(strcmp(app.Kind.Value,'motion'));
            app.SimulateButton.Enable=matlab.lang.OnOffSwitchState(~isempty(app.Reference));
            app.RestoreButton.Enable=matlab.lang.OnOffSwitchState(~isempty(app.Input));
            app.ExportButton.Enable=matlab.lang.OnOffSwitchState(~isempty(app.Output));
            if isempty(app.Output), app.MetricsTable.Data={};
            else
                d=table2cell(app.Output.metrics); d(:,1)={'输入';'仅锐化';'维纳复原';'学习修正';'最终输出'};
                for i=1:size(d,1), for j=2:size(d,2)
                    if isnan(d{i,j}), d{i,j}='—'; else, d{i,j}=sprintf('%.4f',d{i,j}); end
                end, end
                app.MetricsTable.Data=d;
            end
        end
        function export(app)
            folder=uigetdir(app.Config.root,'选择结果保存位置'); if isequal(folder,0), return; end
            try
                folder=fullfile(folder,['restore_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);
                restorelab.export_result(app.Output,folder,app.Reference);
                restorelab.comparison(app.Output,app.Reference,fullfile(folder,'comparison.png'),'Image restoration');
                app.Status.Text=['已导出：' folder];
            catch err, app.fail(err); end
        end
        function train(app)
            d=uiprogressdlg(app.Figure,'Title','训练模型','Message','正在训练和验证，请稍候…','Indeterminate','on');
            clean=onCleanup(@()close(d));
            try
                app.Model=train_project(); app.Amount.Value=app.Model.sharpAmount; app.clearOutput();
                app.Status.Text='训练完成，已载入新模型；需重新复原以应用新模型。';
            catch err, app.fail(err); end
        end
        function help(app)
            file=fullfile(app.Config.root,'docs','使用手册.html');
            if isfile(file), web(file,'-browser'); else, uialert(app.Figure,'请阅读根目录 README.txt。','使用说明'); end
        end
        function fail(app,err)
            app.Status.Text=['操作未完成：' err.message];
            if strcmp(app.Figure.Visible,'on'), uialert(app.Figure,err.message,'请检查输入'); else, rethrow(err); end
        end
        function delete(app)
            if ~isempty(app.Figure) && isvalid(app.Figure), delete(app.Figure); end
        end
    end
end
