function report = run_batch(inputFolder,outputFolder,preset)
%RUN_BATCH 无界面批处理：run_batch('输入目录','输出目录','natural')。
root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'src'));cartoon_check_environment();
if nargin<1,inputFolder=fullfile(root,'samples');end
if nargin<2,outputFolder=fullfile(root,'exports');end
if nargin<3,preset='natural';end
if ~isfolder(inputFolder),error('Cartoon:Folder','输入目录不存在。');end
files=dir(inputFolder);paths={};metadata={};samples=cartoon_samples(root);
for k=1:numel(files)
    [~,~,ext]=fileparts(files(k).name);
    if ~files(k).isdir && ismember(lower(ext),{'.jpg','.jpeg','.png','.bmp','.tif','.tiff'})
        paths{end+1}=fullfile(inputFolder,files(k).name); %#ok<AGROW>
        j=find(strcmp({samples.file},files(k).name),1);meta=[];
        if ~isempty(j) && strcmpi(inputFolder,fullfile(root,'samples')),meta=samples(j);end
        metadata{end+1}=meta; %#ok<AGROW>
    end
end
report=cartoon_batch(paths,outputFolder,cartoon_defaults(preset), ...
    @(i,n,path)fprintf('[%d/%d] %s\n',i,n,path),@()false,metadata);
fprintf('完成 %d / %d，失败 %d\n输出：%s\n',report.Passed,report.Requested,report.Failed,report.Folder);
end
