function [X,boxes,names] = fp_features(I)
% Sixteen interpretable features per non-overlapping 32x32 block.
names={'mean','contrast','entropy','grad_mean','grad_std','lap_energy', ...
    'coherence','dark_fraction','bright_fraction','residual','p10','p90', ...
    'local_std','low_std_fraction','horizontal_diff','vertical_diff'};
X=zeros(64,16); boxes=zeros(64,4); k=0;
for r=1:32:256
    for c=1:32:256
        k=k+1; P=I(r:r+31,c:c+31); [gx,gy]=gradient(P); gm=hypot(gx,gy);
        a=mean(gx(:).^2);b=mean(gy(:).^2);d=mean(gx(:).*gy(:));
        coh=sqrt((a-b)^2+4*d^2)/(a+b+eps);
        L=imfilter(P,[0 1 0;1 -4 1;0 1 0],'replicate');
        R=P-imgaussfilt(P,1); S=stdfilt(P,true(5));
        dx=diff(P,1,2);dy=diff(P,1,1); v=P(:);
        X(k,:)=[mean(v),std(v),entropy(P),mean(gm(:)),std(gm(:)), ...
            mean(L(:).^2),coh,mean(v<0.12),mean(v>0.9),mean(abs(R(:))), ...
            prctile(v,10),prctile(v,90),mean(S(:)),mean(S(:)<0.025), ...
            mean(abs(dx(:))),mean(abs(dy(:)))];
        boxes(k,:)=[c,r,32,32];
    end
end
end
