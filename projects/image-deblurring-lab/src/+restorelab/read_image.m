function I = read_image(file,maxSide)
% Indexed / uint16 / alpha input supported; composite alpha on white.
if nargin<2, maxSide=Inf; end
[A,map,alpha]=imread(file);
if ~isempty(map), A=ind2rgb(A,map); end
I=im2double(A);
if ~isempty(alpha)
    alpha=im2double(alpha); I=I.*alpha+(1-alpha);
end
if ndims(I)>3 || ~(size(I,3)==1 || size(I,3)==3)
    error('RestoreLab:Input','仅支持灰度或 RGB 图像。');
end
if min(size(I,1),size(I,2))<32
    error('RestoreLab:Input','图像的宽和高都必须至少为 32 像素。');
end
if any(~isfinite(I(:))), error('RestoreLab:Input','图像包含非有限值。'); end
I=restorelab.clip(I);
if max(size(I,1),size(I,2))>maxSide
    I=imresize(I,maxSide/max(size(I,1),size(I,2)));
    % Bicubic interpolation can overshoot at high-contrast edges.
    I=restorelab.clip(I);
end
end
