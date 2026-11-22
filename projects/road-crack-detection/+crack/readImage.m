function [rgb,gray] = readImage(input,maxDimension)
if nargin < 2, maxDimension = 480; end
if ischar(input) || isstring(input), input = imread(input); end
if isempty(input) || ndims(input)>3 || ~(size(input,3)==1 || size(input,3)==3)
    error('crack:Input','请选择有效的灰度或 RGB 图片。');
end
if any(~isfinite(double(input(:)))), error('crack:Input','图像包含非有限数值。'); end
input = im2uint8(input);
if size(input,3)==1, rgb = repmat(input,1,1,3); else, rgb=input; end
if max(size(rgb,1:2)) > maxDimension
    rgb = imresize(rgb,maxDimension/max(size(rgb,1:2)));
end
gray = im2single(rgb2gray(rgb));
end
