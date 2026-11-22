function q = quantify(mask,mmPerPixel)
% 骨架图的相邻边求和；避免把同一条边计两次。
if nargin<2, mmPerPixel=0; end
mask=logical(mask);
skel=bwskel(mask);
% 去除有直角连接时冗余的对角边，减少阶梯骨架的重复计长。
h=nnz(skel(:,1:end-1)&skel(:,2:end));
v=nnz(skel(1:end-1,:)&skel(2:end,:));
a=skel(1:end-1,1:end-1); b=skel(2:end,2:end);
d1=nnz(a&b&~skel(1:end-1,2:end)&~skel(2:end,1:end-1));
a=skel(1:end-1,2:end); b=skel(2:end,1:end-1);
d2=nnz(a&b&~skel(1:end-1,1:end-1)&~skel(2:end,2:end));
lengthPx=h+v+sqrt(2)*(d1+d2);
% 边缘外补背景，确保满幅掩膜的距离变换仍有有限距离。
dist=bwdist(~padarray(mask,[1 1],false)); dist=dist(2:end-1,2:end-1);
widths=max(2*dist(skel)-1,0);
if isempty(widths), meanW=0; maxW=0; p95=0; else
    meanW=mean(widths); maxW=max(widths); ws=sort(widths); p95=ws(max(1,ceil(0.95*numel(ws))));
end
cc=bwconncomp(mask,8);
q=struct('areaPx',nnz(mask),'areaRate',nnz(mask)/numel(mask), ...
    'lengthPx',lengthPx,'meanWidthPx',meanW,'maxWidthPx',maxW,'p95WidthPx',p95, ...
    'components',cc.NumObjects,'branchPixels',nnz(bwmorph(skel,'branchpoints')), ...
    'skeleton',skel,'widthMap',max(2*dist-1,0).*single(skel),'widthsPx',widths, ...
    'mmPerPixel',mmPerPixel,'lengthMm',NaN,'meanWidthMm',NaN);
if mmPerPixel>0, q.lengthMm=lengthPx*mmPerPixel; q.meanWidthMm=meanW*mmPerPixel; end
end
