function r = cartoon_process(input,p,progress)
%CARTOON_PROCESS 基于 spencerwooo/cartoonize-images 的 MATLAB 改进实现。
% 保留其饱和度增强→Lab 双边滤波→轮廓合成主流程和 MIT 署名。
% 新增：可控量化/色彩混合、自适应双阈值、轮廓清理与柔化、完整输入校验。
if nargin<2, p=cartoon_defaults(); end
if nargin<3, progress=@(~)[]; end
validateattributes(input,{'uint8','uint16','single','double','logical'},{'nonempty','real','finite'});
if ndims(input)>3 || ~ismember(size(input,3),[1 3]) || min(size(input,1),size(input,2))<3
    error('Cartoon:Input','输入应为至少 3×3 的灰度或 RGB 图像。');
end
if isfloat(input) && (min(input(:))<0 || max(input(:))>1), error('Cartoon:Range','浮点图像必须位于 [0,1]。'); end
validateattributes(p.Colors,{'numeric'},{'scalar','finite','integer','>=',4,'<=',64});
for key={'SmoothStrength','EdgeDetail','InkStrength','ColorBlend'}
    validateattributes(p.(key{1}),{'numeric'},{'scalar','finite','>=',0,'<=',1});
end
validateattributes(p.Saturation,{'numeric'},{'scalar','finite','>=',0.5,'<=',1.5});
validateattributes(p.SmoothPasses,{'numeric'},{'scalar','integer','>=',0,'<=',3});
validateattributes(p.LineWidth,{'numeric'},{'scalar','integer','>=',1,'<=',3});
validateattributes(p.MaxDimension,{'numeric'},{'scalar','finite','integer','>=',64,'<=',2400});
if ~ismember(p.Mode,{'color','sketch'}), error('Cartoon:Mode','无效处理模式。'); end
t=tic; a=im2uint8(input); if size(a,3)==1,a=repmat(a,1,1,3);end
inputSize=[size(a,1),size(a,2)];scale=min(1,p.MaxDimension/max(inputSize));
if scale<1,a=imresize(a,scale);end
progress('1/4 色彩增强与保边平滑');
enhanced=saturateImage(a,p.Saturation);
lab=rgb2lab(enhanced);
% 用有界、可解释的参数替换上游固定坐标裁块估计，兼容小图与不同构图。
n=min(11,2*floor((min(size(a,1),size(a,2))-2)/2)+1);
smoothness=20+280*p.SmoothStrength^2; sigma=1.5+3*p.SmoothStrength;
for k=1:p.SmoothPasses
    lab=imbilatfilt(lab,smoothness,sigma,'NeighborhoodSize',n);
end
smooth=lab2rgb(lab,'OutputType','uint8');
progress('2/4 简化色块');
[index,map]=rgb2ind(smooth,p.Colors,'nodither');
quantized=im2uint8(ind2rgb(index,map));
progress('3/4 提取并整理轮廓');
gray=medfilt2(rgb2gray(smooth),[3 3],'symmetric');
threshold=[0 0];edges=false(size(gray));
if p.EdgeDetail>0 && max(gray(:))>min(gray(:))
    edgeSigma=1.1+.6*p.SmoothStrength;
    [~,automatic]=edge(gray,'Canny',[],edgeSigma);
    high=min(.45,max(.04,automatic(2)*(1.65-1.25*p.EdgeDetail)));
    threshold=[.4*high high];edges=edge(gray,'Canny',threshold,edgeSigma);
    edges=bwareaopen(edges,max(3,round(5*max(size(gray))/1000)),8);
    if p.LineWidth>1,edges=imdilate(edges,strel('disk',p.LineWidth-1,0));end
end
ink=min(1,.75*double(edges)+.5*imgaussfilt(double(edges),.55));
progress('4/4 合成与统计');
if strcmp(p.Mode,'sketch')
    result=repmat(im2uint8(1-ink),1,1,3);
else
    color=(1-p.ColorBlend)*im2double(quantized)+p.ColorBlend*im2double(smooth);
    result=im2uint8(color.*(1-p.InkStrength*ink));
end
grayIn=im2double(rgb2gray(a));grayOut=im2double(rgb2gray(result));
metrics=struct('MeanBrightness',mean(grayIn(:)), ...
    'Contrast',std(grayIn(:)), 'EdgePercent',100*nnz(edges)/numel(edges), ...
    'MeanAbsoluteChange',mean(abs(grayIn(:)-grayOut(:))));
r=struct('Original',a,'Enhanced',enhanced,'Smoothed',smooth,'Quantized',quantized, ...
    'Edges',edges,'Outline',im2uint8(1-ink),'Result',result,'Params',p, ...
    'InputSize',inputSize,'Scale',scale,'PaletteSize',size(map,1),'Palette',map, ...
    'EdgeRatio',nnz(edges)/numel(edges),'EffectiveThreshold',threshold, ...
    'Metrics',metrics,'Elapsed',toc(t));
end
