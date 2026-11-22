function report = batch_restore(inputFolder,outputFolder,kind,strength,angle,noiseSigma,amount)
% BATCH_RESTORE Process real inputs; never fabricate full-reference metrics.
% Example: batch_restore('my_images','my_results','gaussian',1.5,0,0.015,0.15)
if nargin<3, kind='gaussian'; end
if nargin<4, strength=1.5; end
if nargin<5, angle=0; end
if nargin<6, noiseSigma=0.015; end
if nargin<7, amount=[]; end
c=setup_project(); model=restorelab.load_model(c); p=struct('kind',kind,'strength',strength,'angle',angle);
restorelab.make_psf(p); files=dir(inputFolder); rows={};
for i=1:numel(files)
    [~,stem,ext]=fileparts(files(i).name);
    if files(i).isdir || ~ismember(lower(ext),{'.png','.jpg','.jpeg','.tif','.tiff','.bmp'}), continue; end
    try
        I=restorelab.read_image(fullfile(inputFolder,files(i).name),2048);
        out=restorelab.process(I,p,noiseSigma,model,amount,[]);
        % File extension retained in folder name to prevent same-stem collisions.
        dst=fullfile(outputFolder,[stem '_' ext(2:end)]);
        if exist(dst,'dir'), error('RestoreLab:Exists','输出目录已存在，请换一个输出位置。'); end
        restorelab.export_result(out,dst);
        restorelab.comparison(out,[],fullfile(dst,'comparison.png'),files(i).name);
        rows(end+1,:)={files(i).name,'ok',out.seconds,''}; %#ok<AGROW>
    catch err
        rows(end+1,:)={files(i).name,'error',NaN,err.message}; %#ok<AGROW>
    end
end
if isempty(rows), error('RestoreLab:EmptyFolder','输入文件夹没有支持的图像。'); end
report=cell2table(rows,'VariableNames',{'File','Status','Seconds','Message'});
if ~exist(outputFolder,'dir'), mkdir(outputFolder); end
writetable(report,fullfile(outputFolder,'batch_report.csv'),'Encoding','UTF-8');
end
