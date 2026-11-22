function summary = run_analysis()
%RUN_ANALYSIS 对 12 张新照片实际运行 V1 与 V2，保存可复现对比和统计。
root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'src'));cartoon_check_environment();
samples=cartoon_samples(root);output=fullfile(root,'analysis');if ~isfolder(output),mkdir(output);end
names={'natural','comic','poster','sketch'};rows=struct([]);
for i=1:numel(samples)
    input=read_image_safe(fullfile(root,'samples',samples(i).file));
    folder=fullfile(output,samples(i).id);if ~isfolder(folder),mkdir(folder);end
    old=cartoon_v1_defaults();old.MaxDimension=640;v1=cartoon_v1(input,old);
    imwrite(v1.Original,fullfile(folder,'original.jpg'));imwrite(v1.Result,fullfile(folder,'v1.png'));
    pictures={v1.Original,v1.Result};
    for j=1:numel(names)
        p=cartoon_defaults(names{j});p.MaxDimension=640;r=cartoon_process(input,p);
        imwrite(r.Result,fullfile(folder,[names{j} '.png']));pictures{end+1}=r.Result; %#ok<AGROW>
        row=struct('Photo',samples(i).id,'Category',samples(i).category,'Style',names{j}, ...
            'Width',size(r.Result,2),'Height',size(r.Result,1),'Palette',r.PaletteSize, ...
            'EdgePercent',100*r.EdgeRatio,'Seconds',r.Elapsed, ...
            'Brightness',r.Metrics.MeanBrightness,'Contrast',r.Metrics.Contrast, ...
            'MeanAbsoluteChange',r.Metrics.MeanAbsoluteChange);
        if isempty(rows),rows=row;else,rows(end+1)=row;end %#ok<AGROW>
        cartoon_write_json(fullfile(folder,[names{j} '_parameters.json']),struct('Parameters',p,'Metrics',r.Metrics,'Source',samples(i)));
    end
    gap=repmat(uint8(248),size(v1.Original,1),8,3);strip=pictures{1};
    for j=2:numel(pictures),strip=[strip gap pictures{j}];end %#ok<AGROW>
    imwrite(strip,fullfile(folder,'compare_original_v1_four_styles.jpg'));
    fprintf('PHOTO_ANALYZED %d/%d %s\n',i,numel(samples),samples(i).id);
end
writetable(struct2table(rows),fullfile(output,'实测统计.csv'),'Encoding','UTF-8');
summary=struct('PhotoCount',numel(samples),'V2Results',numel(rows),'ComparisonLongEdge',640, ...
    'Note','V1 与 V2 均使用长边 640；各自使用默认预设，参数不同。统计不是美感或客观画质排名。', ...
    'Results',rows);
cartoon_write_json(fullfile(output,'analysis_summary.json'),summary);
disp('ANALYSIS_ALL_PHOTOS_PASS');
end
