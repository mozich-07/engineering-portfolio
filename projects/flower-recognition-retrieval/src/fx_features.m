function [f,preview,parts] = fx_features(source)
%FLOWER_FEATURES 固定的无学习特征。归一化参数在训练脚本中仅由训练集拟合。
% 参考 Gogul09/image-classification-python 的颜色与纹理融合思路，MATLAB重写。
cfg=fx_config(); I=fx_read(source);
% 双三次插值可能产生略小于0或大于1的值，先截断再计算HSV量化下标。
I=min(max(imresize(I,cfg.imageSize),0),1); hsv=rgb2hsv(I); gray=rgb2gray(I);
regions={I,I(41:120,41:120,:),I(1:80,1:80,:),I(1:80,81:160,:), ...
    I(81:160,1:80,:),I(81:160,81:160,:)};
color=[]; texture=[];
for r=1:numel(regions)
    H=rgb2hsv(regions{r});
    h=histcounts(H(:,:,1),linspace(0,1,17));
    s=histcounts(H(:,:,2),linspace(0,1,9));
    v=histcounts(H(:,:,3),linspace(0,1,9));
    block=[h/sum(h),s/sum(s),v/sum(v)];
    color=[color sqrt(block)]; %#ok<AGROW>
    moments=[];
    for c=1:3
        x=H(:,:,c); x=x(:); mu=mean(x); third=mean((x-mu).^3);
        moments=[moments mu std(x) sign(third)*abs(third)^(1/3)]; %#ok<AGROW>
    end
    color=[color moments]; %#ok<AGROW>
    texture=[texture uniform_lbp(im2uint8(rgb2gray(regions{r})))]; %#ok<AGROW>
end
% 联合颜色直方图保留色调、饱和度、亮度之间的关系。
for r=1:2
    H=rgb2hsv(regions{r});
    q=min(floor(H.*reshape([16 4 4],1,1,3)),reshape([15 3 3],1,1,3));
    idx=1+q(:,:,1)+16*q(:,:,2)+64*q(:,:,3);
    joint=accumarray(idx(:),1,[256 1]);
    color=[color sqrt(joint'/sum(joint))]; %#ok<AGROW>
end
offsets=[0 1;-1 1;-1 0;-1 -1];
glcm=graycomatrix(gray,'NumLevels',8,'GrayLimits',[0 1],'Offset',offsets,'Symmetric',true);
st=graycoprops(glcm,{'Contrast','Correlation','Energy','Homogeneity'});
g=[st.Contrast/49;st.Correlation;st.Energy;st.Homogeneity]; g(~isfinite(g))=0;
texture=[texture mean(g,2)' std(g,0,2)'];
% 简化梯度方向直方图：4×4网格，每格9个方向，180度无符号。
[gx,gy]=gradient(gray); mag=hypot(gx,gy); theta=mod(atan2(gy,gx),pi);
gradientFeature=[];
for row=0:3
    for col=0:3
        rr=row*40+(1:40); cc=col*40+(1:40);
        b=min(floor(theta(rr,cc)/pi*9),8)+1; w=mag(rr,cc);
        z=accumarray(b(:),w(:),[9 1]); z=z/(norm(z)+eps);
        gradientFeature=[gradientFeature z']; %#ok<AGROW>
    end
end
color=color/(norm(color)+eps);
texture=texture/(norm(texture)+eps);
gradientFeature=gradientFeature/(norm(gradientFeature)+eps);
f=[color 0.75*texture 0.5*gradientFeature];
parts.color=1:numel(color);
parts.texture=numel(color)+(1:numel(texture));
parts.gradient=numel(color)+numel(texture)+(1:numel(gradientFeature));
preview.rgb=I; preview.gray=gray; preview.edges=edge(gray,'Canny');
preview.hue=histcounts(hsv(:,:,1),linspace(0,1,17),'Normalization','probability');
end

function h = uniform_lbp(A)
% 8邻域均匀LBP：58种均匀模式与1个非均匀模式。无需计算机视觉工具箱。
persistent mapping
if isempty(mapping)
    mapping=59*ones(256,1); count=0;
    for code=0:255
        bits=bitget(uint8(code),1:8);
        if sum(bits~=bits([2:8 1]))<=2
            count=count+1; mapping(code+1)=count;
        end
    end
end
C=A(2:end-1,2:end-1); code=zeros(size(C),'uint8');
dr=[-1 -1 -1 0 1 1 1 0]; dc=[-1 0 1 1 1 0 -1 -1];
for k=1:8
    neighbor=A((2:size(A,1)-1)+dr(k),(2:size(A,2)-1)+dc(k));
    code=bitor(code,bitshift(uint8(neighbor>=C),k-1));
end
counts=accumarray(mapping(double(code(:))+1),1,[59 1]);
h=sqrt(counts'/sum(counts));
end
