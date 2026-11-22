function [rgb, info] = read_image_safe(path)
%READ_IMAGE_SAFE 灰度转 RGB，索引色解码，透明区域与白底合成。
if ~(ischar(path) || (isstring(path) && isscalar(path))) || ~isfile(path)
    error('Cartoon:File','图片不存在，请重新选择 JPG、PNG、BMP 或 TIFF 文件。');
end
[~,~,ext] = fileparts(path);
if ~ismember(lower(ext),{'.jpg','.jpeg','.png','.bmp','.tif','.tiff'})
    error('Cartoon:Format','只支持 JPG、PNG、BMP、TIF 和 TIFF。');
end
try
    meta=imfinfo(path); meta=meta(1);
    if double(meta.Width)*double(meta.Height)>4e7
        error('Cartoon:LargeImage','图片超过 4000 万像素，请先缩小后导入。');
    end
    [a,map,alpha]=imread(path);
catch err
    if startsWith(err.identifier,'Cartoon:'), rethrow(err); end
    error('Cartoon:Read','无法读取图片，文件可能已损坏或格式不支持。');
end
if ~isempty(map), a=im2uint8(ind2rgb(a,map)); end
if ndims(a)>3 || size(a,3)>3
    error('Cartoon:Channels','不支持此图像通道布局，请另存为普通 RGB PNG。');
end
a=im2uint8(a);
if size(a,3)==1, a=repmat(a,1,1,3); end
if ~isempty(alpha)
    opacity=im2double(alpha);
    a=im2uint8(im2double(a).*opacity + (1-opacity));
end
rgb=a;
info=struct('Name',char(path),'Width',size(a,2),'Height',size(a,1), ...
    'Transparent',~isempty(alpha),'FramesUsed',1);
end
