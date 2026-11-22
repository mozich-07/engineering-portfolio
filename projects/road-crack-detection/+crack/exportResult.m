function folder = exportResult(r,folder,name)
if nargin<3, name='result'; end
if ~isfolder(folder), mkdir(folder); end
name=regexprep(char(name),'[^\w\-]','_');
imwrite(r.rgb,fullfile(folder,[name '_original.png']));
imwrite(r.overlay,fullfile(folder,[name '_overlay.png']));
imwrite(r.mask,fullfile(folder,[name '_mask.png']));
imwrite(r.quant.skeleton,fullfile(folder,[name '_skeleton.png']));
imwrite(im2uint8(mat2gray(r.score)),fullfile(folder,[name '_response.png']));
q=rmfield(r.quant,{'skeleton','widthMap','widthsPx'});
record=q; record.method=string(r.method); record.seconds=r.seconds;
writetable(struct2table(record),fullfile(folder,[name '_measurements.csv']),'Encoding','UTF-8');
save(fullfile(folder,[name '_result.mat']),'r');
meta=struct('parameters',r.parameters,'measurements',q,'method',r.method,'seconds',r.seconds, ...
    'note','长度和宽度为分割掩膜的二维估计值；未标定时单位为处理图像像素。');
fid=fopen(fullfile(folder,[name '_metadata.json']),'w','n','UTF-8');
assert(fid~=-1,'无法写入结果目录。'); cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s',jsonencode(meta,PrettyPrint=true));
end
