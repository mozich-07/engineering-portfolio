function [X,maps] = features(gray,p)
% 多尺度暗线 + 局部亮度/纹理特征；输出为每个像素的一行。
% Frangi 特征使用保留在 third_party 中的开源实现，未改写其核心。
g = imgaussfilt(gray,0.65);
background = imgaussfilt(g,12);
localStd = stdfilt(g,true(9));
dark = max(background-g,0);
z = (background-g)./(localStd+0.015);
enhanced = adapthisteq(g,'ClipLimit',0.008,'NumTiles',[8 8]);
bh3 = imbothat(g,strel('disk',3,0));
bh7 = imbothat(g,strel('disk',7,0));
[gx,gy] = gradient(g);
grad = hypot(gx,gy);
v = zeros([size(g),numel(p.scales)],'single');
for k=1:numel(p.scales)
    sigma=p.scales(k);
    opt=struct('FrangiScaleRange',[sigma sigma],'FrangiScaleRatio',1, ...
        'FrangiBetaOne',0.5,'FrangiBetaTwo',8,'BlackWhite',true, ...
        'FWHM',false,'verbose',false);
    v(:,:,k)=single(FrangiFilter2D(double(g)*255,opt));
end
ridge=max(v,[],3);
planes=cat(3,g,dark,z,localStd,bh3,bh7,grad,enhanced,v);
X=reshape(planes,[],size(planes,3));
maps=struct('gray',gray,'enhanced',enhanced,'dark',dark, ...
    'ridge',ridge,'blackhat',bh7,'localStd',localStd);
end
