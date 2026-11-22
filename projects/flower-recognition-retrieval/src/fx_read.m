function I = fx_read(source)
%READ_FLOWER_IMAGE 统一处理 RGB、灰度、索引图、透明图和 uint16。
if ischar(source) || isstring(source)
    if ~isfile(source), error('Flower:MissingImage','图片文件不存在。'); end
    info=imfinfo(source);
    if info(1).Width*info(1).Height>40000000
        error('Flower:TooLarge','图片超过 4000 万像素，请缩小后再导入。');
    end
    [I,map,alpha]=imread(source);
    if ~isempty(map), I=ind2rgb(I,map); end
else
    I=source; alpha=[];
end
if isempty(I) || ~isnumeric(I) && ~islogical(I)
    error('Flower:InvalidImage','图片为空或格式不受支持。');
end
if ndims(I)>3 || size(I,3)~=1 && size(I,3)~=3
    error('Flower:Channels','仅支持灰度图与 RGB 图像。');
end
I=im2double(I);
if any(~isfinite(I(:))) || any(I(:)<0) || any(I(:)>1)
    error('Flower:Range','图像像素必须是有限值，浮点图像范围为 0 到 1。');
end
if size(I,3)==1, I=repmat(I,1,1,3); end
if ~isempty(alpha)
    a=im2double(alpha); I=I.*a+(1-a);
end
if min(size(I,1),size(I,2))<16
    error('Flower:TooSmall','图片尺寸至少为 16 × 16 像素。');
end
end
