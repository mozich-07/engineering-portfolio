function R = fp_process(input,model,options)
% Deterministic enhancement + supervised quality gate + crossing-number minutiae.
if nargin<3,options=struct;end
if isfield(options,'mode')&&strcmp(options.mode,'real'),R=fp_process_real(input,model,options);return;end
if ~isfield(options,'useML'),options.useML=true;end
if ~isfield(options,'threshold'),options.threshold=model.threshold;end
clockStart=tic;[I,meta]=fp_read(input);
[X,boxes]=fp_features(I);p=fp_probability(X,model);
Q=zeros(size(I));for k=1:64
    c=boxes(k,1);r=boxes(k,2);Q(r:r+31,c:c+31)=p(k);
end
Q=imgaussfilt(Q,6);
J=medfilt2(I,[3 3],'symmetric');J=adapthisteq(J,'NumTiles',[8 8],'ClipLimit',0.01);
S=imgaussfilt(J,1);[gx,gy]=gradient(S);
a=imgaussfilt(gx.^2,5);b=imgaussfilt(gy.^2,5);d=imgaussfilt(gx.*gy,5);
coh=sqrt((a-b).^2+4*d.^2)./(a+b+eps);theta=mod(0.5*atan2(2*d,a-b),pi);
texture=stdfilt(J,true(9));mask=imgaussfilt(I,3)<0.94 & texture>0.035;
mask=imclose(mask,strel('disk',7,0));mask=imfill(mask,'holes');mask=bwareaopen(mask,350);
mask([1:9,end-8:end],:)=false;mask(:,[1:9,end-8:end])=false;
[xx,yy]=meshgrid(-12:12);response=zeros(size(I));
for k=0:11
    ang=k*pi/12;u=xx*cos(ang)+yy*sin(ang);v=-xx*sin(ang)+yy*cos(ang);
    kernel=exp(-0.5*(u.^2/4^2+v.^2/7^2)).*cos(2*pi*u/9);kernel=kernel-mean(kernel(:));
    kernel=kernel/sum(abs(kernel(:)));F=imfilter(J,kernel,'symmetric');
    select=mod(round(theta/pi*12),12)==k;response(select)=F(select);
end
% Ridge polarity is retained, not the magnitude of the Gabor response.
E=mat2gray(response,[-0.16 0.16]);E=0.8*E+0.2*J;E(~mask)=1;
B=E<adaptthresh(E,0.48,'ForegroundPolarity','dark') & mask;
B=bwareaopen(B,18);skel=bwmorph(B,'thin',Inf);skel=bwmorph(skel,'spur',4);
% CN transitions in ordered 8-neighbourhood: 1=end, 3=bifurcation.
neighbors=cat(3,circshift(skel,[-1 0]),circshift(skel,[-1 1]),circshift(skel,[0 1]), ...
    circshift(skel,[1 1]),circshift(skel,[1 0]),circshift(skel,[1 -1]),circshift(skel,[0 -1]),circshift(skel,[-1 -1]));
cn=sum(abs(diff(double(cat(3,neighbors,neighbors(:,:,1))),1,3)),3)/2;
candidate=skel & (cn==1 | cn==3) & bwdist(~mask)>10 & coh>0.15;
[ys,xs]=find(candidate);types=cn(candidate);scores=Q(candidate);localcoh=coh(candidate);
% Cluster suppression favors coherent, lower-risk points of the same type.
[~,order]=sort(localcoh-scores*0.25,'descend');keep=false(numel(xs),1);
for z=order(:)'
    if ~any(keep & types==types(z) & hypot(xs-xs(z),ys-ys(z))<7),keep(z)=true;end
end
xs=xs(keep);ys=ys(keep);types=types(keep);scores=scores(keep);
reliable=mask & Q<options.threshold;
distance=bwdist(~reliable);ind=sub2ind(size(I),ys,xs);
accepted=true(size(xs));if options.useML,accepted=scores<options.threshold & distance(ind)>7;end
angle=mod(theta(ind)*180/pi+90,180);
sourceX=(xs-0.5)/meta.scale(1)+0.5+meta.offset(1);sourceY=(ys-0.5)/meta.scale(2)+0.5+meta.offset(2);
points=table(xs,ys,sourceX,sourceY,types,angle,scores,accepted,'VariableNames', ...
    {'x256','y256','sourceX','sourceY','crossingNumber','ridgeDirectionDeg','damageScore','accepted'});
if nnz(mask)<500 || std(I(:))<0.015
    points=points([],:);status='未发现足够的指纹纹理，请重新采集。';
elseif nnz(reliable)/max(nnz(mask),1)<0.35
    status='可用纹理不足，建议重新采集；遮盖内部不重建细节点。';
else
    status='请人工核对端点与分叉点。';
end
if max(meta.originalSize)>300
    status=[status ' 输入尺度不同于训练样本，须检查文字或背景误检。'];
end
R=struct('original',I,'enhanced',E,'binary',B,'skeleton',skel,'mask',mask,'quality',Q, ...
    'coherence',coh,'points',points,'meta',meta,'options',options,'status',status, ...
    'endings',nnz(points.accepted & points.crossingNumber==1), ...
    'bifurcations',nnz(points.accepted & points.crossingNumber==3), ...
    'rejected',nnz(~points.accepted),'reliableFraction',nnz(reliable)/max(nnz(mask),1),'seconds',toc(clockStart));
end
