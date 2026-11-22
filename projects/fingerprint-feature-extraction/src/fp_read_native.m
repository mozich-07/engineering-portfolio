function [I,meta,A] = fp_read_native(input,options)
if nargin<2,options=struct;end
if ischar(input)||isstring(input)
    [A,map]=imread(input);if ~isempty(map),A=ind2rgb(A,map);end
else,A=input;end
if isempty(A)||ndims(A)>3||min(size(A,1),size(A,2))<32,error('Fingerprint:Input','请导入至少 32×32 像素的指纹图片。');end
if any(~isfinite(double(A(:)))),error('Fingerprint:Input','图像包含无效数值。');end
A=im2double(A);if min(A(:))<0||max(A(:))>1,A=mat2gray(A);end
meta.originalSize=[size(A,1),size(A,2)];meta.offset=[0 0];meta.channel='灰度';
if size(A,3)==3
    if isfield(options,'channel')&&ismember(options.channel,{'red','green','blue'})
        n=find(strcmp(options.channel,{'red','green','blue'}));I=A(:,:,n);meta.channel=options.channel;
    else,I=rgb2gray(A);end
else,I=A;end
% Preserve aspect ratio and visible ridge detail; small sensor images retain their native geometry.
if isequal(size(I),[103 96])||isequal(size(I),[96 103]),I=I(5:end-4,5:end-4);meta.offset=[4 4];end
meta.contentSize=size(I);scale=min(2,max(1,512/max(size(I))));if max(size(I))>640,scale=640/max(size(I));end
I=imresize(I,scale,'bicubic');I=min(max(I,0),1);meta.scale=[size(I,2)/meta.contentSize(2),size(I,1)/meta.contentSize(1)];
meta.processedSize=size(I);
end
