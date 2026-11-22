function records=fp_batch(files,model,dest,options,progress,cancel)
% Shared headless batch path. Files are explicit so outputs never recurse into inputs.
if nargin<5,progress=@(~,~)[];end
if nargin<6,cancel=@()false;end
if ~isfolder(dest),mkdir(dest);end
rows=cell(0,6);
for i=1:numel(files)
    if cancel(),break;end
    progress(i,numel(files));[~,stem,ext]=fileparts(files{i});
    try
        R=fp_process(files{i},model,options);fp_export(R,dest,sprintf('%03d_%s',i,stem));
        rows(end+1,:)={[stem ext],R.endings,R.bifurcations,R.rejected,R.seconds,'成功'}; %#ok<AGROW>
    catch err
        rows(end+1,:)={[stem ext],NaN,NaN,NaN,NaN,err.message}; %#ok<AGROW>
    end
end
records=cell2table(rows,'VariableNames',{'file','endings','bifurcations','rejected','seconds','status'});
writetable(records,fullfile(dest,'批量汇总.csv'),'Encoding','UTF-8');
end
