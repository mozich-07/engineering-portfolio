function result = enhanceImage(input, options)
%ENHANCEIMAGE 亮度通道直方图增强，所有方法采用相同输入与颜色路径。
arguments
    input
    options.ClipLimit (1,1) double {mustBePositive} = 0.01
    options.Strength (1,1) double {mustBeNonnegative} = 0.75
    options.Denoise (1,1) logical = true
end
assert(options.ClipLimit<=0.1 && options.Strength<=1,'参数超出范围。');
assert(isnumeric(input)||islogical(input),'输入必须是图像数组。');
assert(~isempty(input)&&all(isfinite(input(:))),'图像为空或含非有限数值。');
I=im2double(input); assert(all(I(:)>=0 & I(:)<=1),'浮点输入需位于[0,1]。');
assert(ndims(I)<=3 && (size(I,3)==1||size(I,3)==3),'仅支持灰度或RGB图像。');
assert(min(size(I,1),size(I,2))>=16,'图像宽高至少16像素。');
isColor=size(I,3)==3;
if isColor, lab=rgb2lab(I); L=lab(:,:,1)/100; else, L=I; lab=[]; end
L=min(max(L,0),1); t=tic;
q=sort(L(:)); span=q(max(1,round(.95*numel(q))))-q(max(1,round(.05*numel(q))));
mu=mean(L(:)); gamma=1; alpha=0;
if max(L(:))-min(L(:))<1/255
    layers={L,L,L,L}; note='近似常量图已保持原样，避免放大无意义噪声。';
else
    H=globalHE(L);
    C=adapthisteq(L,'NumTiles',[8 8],'ClipLimit',options.ClipLimit,'NBins',256);
    % 保守的亮度调整：目标均值0.45，幂律只能近似达到目标。
    if mu<.40 || mu>.65, gamma=min(1.35,max(.65,log(.45)/log(max(mu,.001)))); end
    G=L.^gamma;
    if options.Denoise
        smooth=imguidedfilter(G,'NeighborhoodSize',[5 5],'DegreeOfSmoothing',0.0004);
    else, smooth=G; end
    A=adapthisteq(smooth,'NumTiles',[8 8],'ClipLimit',options.ClipLimit,'NBins',256);
    alpha=options.Strength*(.25+.60*(1-min(1,span/.8)));
    F=(1-alpha)*G+alpha*A;
    F=min(max(F+.25*(mean(G(:))-mean(F(:))),0),1);
    layers={L,H,C,F}; note='指标用于解释变化；熵、标准差越大不一定越自然。';
end
names={'原图','全局均衡HE','局部均衡CLAHE','自适应融合'};
images=cell(1,4); histograms=zeros(256,4); metrics=zeros(4,5);
for k=1:4
    if k==1, J=I;
    elseif isColor
        tmp=lab;tmp(:,:,1)=100*layers{k};J=min(max(lab2rgb(tmp),0),1);
    else, J=layers{k}; end
    images{k}=im2uint8(J);
    % 使用实际导出的8位图计算指标，包含RGB转换和量化影响。
    if isColor
        converted=rgb2lab(images{k}); Y=converted(:,:,1)/100;
        delta=sqrt((converted(:,:,2)-lab(:,:,2)).^2+(converted(:,:,3)-lab(:,:,3)).^2);
        chroma=mean(delta(:));
    else, Y=im2double(images{k});chroma=0;end
    counts=imhist(im2uint8(Y),256);p=counts/sum(counts);nz=p(p>0);
    histograms(:,k)=p;
    metrics(k,:)=[mean(Y(:)),std(Y(:),1),-sum(nz.*log2(nz)),100*mean(Y(:)<=.01|Y(:)>=.99),chroma];
end
result=struct('Names',{names},'Images',{images},'Histograms',histograms,'Metrics',metrics,...
    'Gamma',gamma,'Alpha',alpha,'Span',span,'Seconds',toc(t),'Note',note,'Options',options);
end

function J=globalHE(I)
% 256级直方图->CDF->去除首个非零CDF偏置->单调灰度映射。
Q=im2uint8(I);counts=imhist(Q,256);cdf=cumsum(counts)/numel(Q);
first=cdf(find(counts>0,1));
if first>=1, J=I;return;end
lut=max(0,(cdf-first)/(1-first));J=reshape(lut(double(Q(:))+1),size(I));
end
