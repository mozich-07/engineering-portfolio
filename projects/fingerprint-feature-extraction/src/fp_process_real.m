function R=fp_process_real(input,model,options)
% Visible-ridge enhancement. No synthetic-damage classifier deletes real minutiae.
if nargin<3,options=struct;end
if ~isfield(options,'period'),options.period=0;end
if ~isfield(options,'invert'),options.invert=false;end
clockStart=tic;[I,meta]=fp_read_native(input,options);raw=I;[H,W]=size(I);
if options.invert,I=1-I;end
roi=true(H,W);
if isfield(options,'roi')&&~isempty(options.roi)
    v=options.roi;px=(v(:,1)-meta.offset(1)-0.5)*meta.scale(1)+0.5;py=(v(:,2)-meta.offset(2)-0.5)*meta.scale(2)+0.5;
    roi=poly2mask(px,py,H,W);
end
J=medfilt2(I,[3 3],'symmetric');background=imgaussfilt(J,12);
N=J-background;energy=sqrt(imgaussfilt(N.^2,8));N=N./max(energy,0.025);N=max(-3,min(3,N));
period=options.period;
if period<=0
    [fx,fy]=meshgrid((-floor(W/2):ceil(W/2)-1)/W,(-floor(H/2):ceil(H/2)-1)/H);rad=hypot(fx,fy);
    win=(sin(pi*((1:H)'-.5)/H).^2)*(sin(pi*((1:W)-.5)/W).^2);
    power=abs(fftshift(fft2(N.*roi.*win))).^2;periods=4:.5:16;strength=zeros(size(periods));
    for k=1:numel(periods),freq=1/periods(k);ring=abs(rad-freq)<0.008;strength(k)=mean(power(ring))*freq^2;end
    [~,best]=max(strength);period=periods(best);
end
period=max(4,min(16,period));S=imgaussfilt(N,0.7);[gx,gy]=gradient(S);
sigma=max(2,period*0.55);a=imgaussfilt(gx.^2,sigma);b=imgaussfilt(gy.^2,sigma);d=imgaussfilt(gx.*gy,sigma);
coh=sqrt((a-b).^2+4*d.^2)./(a+b+eps);theta=mod(.5*atan2(2*d,a-b),pi);
mask=roi & imgaussfilt(double(coh>.25 & energy>.012),2)>.5;
mask=imclose(mask,strel('disk',round(period),0));mask=imfill(mask,'holes') & roi;mask=bwareaopen(mask,round(period^2*8));
border=max(6,round(period));mask(1:border,:)=false;mask(end-border+1:end,:)=false;mask(:,1:border)=false;mask(:,end-border+1:end)=false;
radius=ceil(2*period);[xx,yy]=meshgrid(-radius:radius);response=zeros(H,W);
for k=0:15
    ang=k*pi/16;u=xx*cos(ang)+yy*sin(ang);v=-xx*sin(ang)+yy*cos(ang);
    kernel=exp(-.5*(u.^2/(.65*period)^2+v.^2/(.85*period)^2)).*cos(2*pi*u/period);
    kernel=kernel-mean(kernel(:));kernel=kernel/sum(abs(kernel(:)));
    F=imfilter(N,kernel,'symmetric');select=mod(round(theta/pi*16),16)==k;response(select)=F(select);
end
E=min(max(.5+response*.65,0),1);E(~roi)=1;
B=response<-.03 & mask;B=bwareaopen(B,round(period*2));skel=bwmorph(B,'thin',Inf);skel=bwmorph(skel,'spur',round(period*.6));
nb=cat(3,circshift(skel,[-1 0]),circshift(skel,[-1 1]),circshift(skel,[0 1]),circshift(skel,[1 1]),circshift(skel,[1 0]),circshift(skel,[1 -1]),circshift(skel,[0 -1]),circshift(skel,[-1 -1]));
cn=sum(abs(diff(double(cat(3,nb,nb(:,:,1))),1,3)),3)/2;
cand=skel & (cn==1|cn==3) & bwdist(~mask)>max(8,period) & coh>.35;
[ys,xs]=find(cand);types=cn(cand);scores=coh(cand);[~,order]=sort(scores,'descend');keep=false(size(xs));
for z=order(:)',if ~any(keep & hypot(xs-xs(z),ys-ys(z))<period*.8),keep(z)=true;end,end
xs=xs(keep);ys=ys(keep);types=types(keep);scores=scores(keep);ind=sub2ind([H W],ys,xs);
sourceX=(xs-.5)/meta.scale(1)+.5+meta.offset(1);sourceY=(ys-.5)/meta.scale(2)+.5+meta.offset(2);
angle=mod(theta(ind)*180/pi+90,180);accepted=true(size(xs));reviewed=false(size(xs));
points=table(xs,ys,sourceX,sourceY,types,angle,scores,accepted,reviewed,'VariableNames',{'x','y','sourceX','sourceY','crossingNumber','ridgeDirectionDeg','localCoherence','accepted','reviewed'});
points=sortrows(points,'localCoherence','descend');
if std(I(:))<.015||nnz(mask)<500,points=points([],:);end
status='已从可见纹线提取候选；请对照原图复核，划痕与边缘仍可能形成伪点。';
if isempty(points),status='此区域未检出稳定细节点。可重新框选、调整纹线间距或更换采集图。';end
options.periodUsed=period;options.mode='real';
R=struct('original',raw,'enhanced',E,'binary',B,'skeleton',skel,'mask',mask,'quality',coh,'coherence',coh,'roi',roi,'points',points,'meta',meta,'options',options,'status',status, ...
    'endings',nnz(points.accepted & points.crossingNumber==1),'bifurcations',nnz(points.accepted & points.crossingNumber==3),'rejected',nnz(~points.accepted),'reliableFraction',nnz(mask)/numel(mask),'seconds',toc(clockStart),'qualityKind','coherence');
if nargin>=2&&isstruct(model)&&isfield(model,'realQuality')
    X=fp_real_features(raw);R.predictedQuality=max(0,min(100,predict(model.realQuality,X)));
end
end
