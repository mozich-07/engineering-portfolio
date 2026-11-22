function report = cartoon_batch(paths,parent,p,progress,cancel,metadata)
%CARTOON_BATCH 单图失败继续；取消在图片之间生效；每次写独立批次。
if nargin<4,progress=@(~,~,~)[];end
if nargin<5,cancel=@()false;end
if nargin<6,metadata=cell(size(paths));end
if ischar(paths)||isstring(paths),paths=cellstr(paths);end
if isempty(paths),error('Cartoon:BatchEmpty','没有可处理的图片。');end
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
folder=fullfile(parent,['batch_' stamp]);suffix=0;
while isfolder(folder),suffix=suffix+1;folder=fullfile(parent,sprintf('batch_%s_%d',stamp,suffix));end
mkdir(folder);
rows=struct('File',{},'Status',{},'Output',{},'Seconds',{},'Message',{});
cancelled=false;
for k=1:numel(paths)
    if cancel(),cancelled=true;break;end
    progress(k,numel(paths),paths{k});
    try
        input=read_image_safe(paths{k});result=cartoon_process(input,p);
        source=struct('File',paths{k});
        if numel(metadata)>=k && ~isempty(metadata{k}),source=metadata{k};end
        exported=export_result(result,folder,source);
        row=struct('File',paths{k},'Status','PASS','Output',exported,'Seconds',result.Elapsed,'Message','');
    catch err
        row=struct('File',paths{k},'Status','FAIL','Output','','Seconds',0,'Message',err.message);
    end
    rows(end+1)=row; %#ok<AGROW>
    report=makeReport();cartoon_write_json(fullfile(folder,'batch_summary.json'),report);
end
report=makeReport();cartoon_write_json(fullfile(folder,'batch_summary.json'),report);
if ~isempty(rows),writetable(struct2table(rows,'AsArray',true),fullfile(folder,'batch_summary.csv'),'Encoding','UTF-8');end
    function report=makeReport()
        report=struct('Folder',folder,'Requested',numel(paths),'Processed',numel(rows), ...
            'Passed',sum(strcmp({rows.Status},'PASS')),'Failed',sum(strcmp({rows.Status},'FAIL')), ...
            'Cancelled',cancelled,'Parameters',p,'Items',rows);
    end
end
