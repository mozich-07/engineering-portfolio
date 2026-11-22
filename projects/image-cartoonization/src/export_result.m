function folder = export_result(r,parent,source)
%EXPORT_RESULT 每次独立目录；完整记录当前参数、来源与中间图。
if nargin<3,source=struct();end
if ~isfolder(parent),mkdir(parent);end
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
folder=fullfile(parent,['cartoon_' stamp]);count=0;
while isfolder(folder),count=count+1;folder=fullfile(parent,sprintf('cartoon_%s_%d',stamp,count));end
mkdir(folder);
try
    imwrite(r.Original,fullfile(folder,'01_original.png'));
    imwrite(r.Smoothed,fullfile(folder,'02_smoothed.png'));
    imwrite(r.Quantized,fullfile(folder,'03_quantized.png'));
    imwrite(r.Outline,fullfile(folder,'04_outline.png'));
    imwrite(r.Result,fullfile(folder,'05_cartoon.png'));
    gap=repmat(uint8(245),size(r.Result,1),12,3);
    imwrite([r.Original gap r.Result],fullfile(folder,'06_comparison.png'));
    meta=struct('Parameters',r.Params,'InputSize',r.InputSize,'OutputSize',size(r.Result), ...
        'Scale',r.Scale,'PaletteSize',r.PaletteSize,'EffectiveThreshold',r.EffectiveThreshold, ...
        'Metrics',r.Metrics,'AlgorithmSeconds',r.Elapsed,'Source',source,'MATLAB',version, ...
        'Note','调色板色数仅统计量化阶段；最终图还包含柔化轮廓与色彩混合。统计量不是主观画质分数。');
    cartoon_write_json(fullfile(folder,'parameters.json'),meta);
    if isfield(source,'license')
        text=sprintf('原图作者：%s\n原图页面：%s\n原图许可：%s\n许可链接：%s\n处理：缩放、色彩增强、平滑、量化和轮廓合成。\nCC BY-SA 原图的衍生图按相同许可分享。\n', ...
            source.author,source.source_page,source.license,source.license_url);
        fid=fopen(fullfile(folder,'图片署名与许可.txt'),'w','n','UTF-8');
        if fid<0,error('Cartoon:Write','无法写入来源文件。');end
        clean=onCleanup(@()fclose(fid));fprintf(fid,'%s',text);clear clean;
    end
catch err
    error('Cartoon:Export','导出未完成：%s',err.message);
end
end
