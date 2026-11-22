function [I,meta] = fp_read(input)
% Read numeric/image input; normalize to 256 square pixels for fixed-scale features.
if ischar(input) || isstring(input)
    [A,map]=imread(input); if ~isempty(map), A=ind2rgb(A,map); end
else
    A=input;
end
if isempty(A) || ndims(A)>3 || min(size(A,1),size(A,2))<32
    error('Fingerprint:Input','图像至少为 32×32 像素，请导入清晰的单枚指纹。');
end
if ndims(A)==3, A=rgb2gray(A(:,:,1:3)); end
if ~all(isfinite(double(A(:)))), error('Fingerprint:Input','图像包含非有限数值。'); end
I=im2double(A); if max(I(:))>1 || min(I(:))<0, I=mat2gray(I); end
meta.originalSize=size(I); meta.offset=[0 0];
% SOCOFing 96x103 scans have a fixed acquisition frame. Only strip that format.
if isequal(size(I),[103 96]) || isequal(size(I),[96 103])
    I=I(5:end-4,5:end-4); meta.offset=[4 4];
end
meta.contentSize=size(I); meta.scale=[256/size(I,2),256/size(I,1)];
I=imresize(I,[256 256],'bicubic'); I=min(max(I,0),1);
end
