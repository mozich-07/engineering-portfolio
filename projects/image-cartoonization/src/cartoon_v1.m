function r = cartoon_v1(input, p)
%CARTOON_PROCESS 可独立测试的主算法，无界面、文件写入或随机状态。
% 基于 projjal1/Image-Cartoonizer 的保边平滑与边缘合成流程移植改进。
% 许可及改动说明见 third_party。Canny 和最小方差量化为新增处理。
if nargin<2, p=cartoon_v1_defaults(); end
validateattributes(input,{'uint8','uint16','single','double','logical'}, ...
    {'nonempty','real','finite'},mfilename,'input');
if ndims(input)>3 || ~ismember(size(input,3),[1 3]) || min(size(input,1),size(input,2))<3
    error('Cartoon:Input','输入应为至少 3×3 的灰度或 RGB 图像。');
end
if isfloat(input) && (min(input(:))<0 || max(input(:))>1)
    error('Cartoon:Range','浮点图像必须归一化到 [0,1]。');
end
validateattributes(p.Colors,{'numeric'},{'scalar','integer','>=',4,'<=',64});
validateattributes(p.SmoothPasses,{'numeric'},{'scalar','integer','>=',0,'<=',4});
validateattributes(p.EdgeThreshold,{'numeric'},{'scalar','finite','>=',0.02,'<=',0.6});
validateattributes(p.EdgeSigma,{'numeric'},{'scalar','finite','>=',0.5,'<=',3});
validateattributes(p.LineWidth,{'numeric'},{'scalar','integer','>=',1,'<=',3});
validateattributes(p.MaxDimension,{'numeric'},{'scalar','integer','>=',64,'<=',1600});
if ~ismember(p.Mode,{'color','sketch'}), error('Cartoon:Mode','无效模式。'); end
t=tic;
a=im2uint8(input);
if size(a,3)==1, a=repmat(a,1,1,3); end
originalSize=[size(a,1),size(a,2)];
scale=min(1,p.MaxDimension/max(originalSize));
if scale<1, a=imresize(a,scale); end
% 1. 双边滤波同时考虑空间距离和颜色距离，减少纹理但保留大轮廓。
s=im2double(a);
neighborhood=min(9,2*floor((min(size(a,1),size(a,2))-2)/2)+1);
for k=1:p.SmoothPasses
    s=imbilatfilt(s,0.025,3,'NeighborhoodSize',neighborhood);
end
smooth=im2uint8(s);
% 2. 最小方差颜色量化；关闭抖动，避免人为引入颗粒。
[index,map]=rgb2ind(smooth,p.Colors,'nodither');
quantized=im2uint8(ind2rgb(index,map));
% 3. 灰度中值滤波后进行 Canny 双阈值检测。
gray=medfilt2(rgb2gray(smooth),[3 3],'symmetric');
% MATLAB Canny 对严格常量图可能放大浮点卷积残差；常量图没有真实边缘。
if max(gray(:))==min(gray(:))
    edges=false(size(gray));
else
    edges=edge(gray,'Canny',[0.4*p.EdgeThreshold p.EdgeThreshold],p.EdgeSigma);
end
edges=bwareaopen(edges,6,8);
if p.LineWidth>1
    edges=imdilate(edges,strel('disk',p.LineWidth-1,0));
end
% 4. 轮廓处设为黑色，其他像素使用量化后的颜色。
if strcmp(p.Mode,'sketch')
    result=repmat(uint8(~edges)*255,1,1,3);
else
    result=quantized;
    result(repmat(edges,1,1,3))=0;
end
r=struct('Original',a,'Smoothed',smooth,'Quantized',quantized, ...
    'Edges',edges,'Result',result,'Params',p,'InputSize',originalSize, ...
    'Scale',scale,'PaletteSize',size(map,1),'EdgeRatio',nnz(edges)/numel(edges), ...
    'Elapsed',toc(t));
end
