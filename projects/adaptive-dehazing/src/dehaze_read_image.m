function rgb = dehaze_read_image(file)
%DEHAZE_READ_IMAGE Decode indexed/grayscale/RGB images consistently.
if ~isfile(file),error('Dehaze:File','图像文件不存在。');end
info=imfinfo(file);
if info(1).Width*info(1).Height>30000000
    error('Dehaze:Size','图像超过 3000 万像素，请先缩小后再处理。');
end
[raw,map,alpha]=imread(file);
if ~isempty(map),rgb=ind2rgb(raw,map);else,rgb=im2double(raw);end
if ismatrix(rgb),rgb=repmat(rgb,1,1,3);end
if size(rgb,3)~=3,error('Dehaze:Channels','文件不是灰度或 RGB 图像。');end
if ~isempty(alpha)
    alpha=im2double(alpha);
    rgb=rgb.*alpha+(1-alpha); % Transparent pixels are composited on white.
end
end
