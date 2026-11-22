function [T,completed]=batch_predict(folder,out,progress)
root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'src'));c=fx_config();m=fx_load();
if nargin<2,out=fullfile(c.root,'exports',['batch_' char(datetime('now','Format','yyyyMMdd_HHmmss')) '.csv']);end
if nargin<3,progress=[];end
files=dir(folder);keep=false(size(files));
for i=1:numel(files)
 [~,~,ext]=fileparts(files(i).name);keep(i)=~files(i).isdir&&ismember(lower(ext),{'.jpg','.jpeg','.png','.bmp','.tif','.tiff'});
end
files=files(keep);rows=cell(0,5);completed=true;
for i=1:numel(files)
 if ~isempty(progress)&&~progress(i-1,numel(files)),completed=false;break;end
 try,r=fx_predict(m,fullfile(folder,files(i).name));rows(end+1,:)={files(i).name,char(r.name),r.topScores(1),r.review,''}; %#ok<AGROW>
 catch ME,rows(end+1,:)={files(i).name,'',NaN,true,ME.message};end %#ok<AGROW>
end
if completed&&~isempty(progress),progress(numel(files),numel(files));end
T=cell2table(rows,'VariableNames',{'File','Prediction','Score','NeedsReview','Error'});parent=fileparts(out);if ~isfolder(parent),mkdir(parent);end
writetable(T,out,'Encoding','UTF-8');
end
