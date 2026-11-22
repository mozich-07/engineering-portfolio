function [D,mask] = fp_degrade(I,kind,seed,severity)
% Reproducible artificial degradation; mask is the affected footprint, not manual minutiae.
if nargin<4, severity=1; end
rs=RandStream('mt19937ar','Seed',seed); D=I;mask=false(size(I));
[xx,yy]=meshgrid(1:256);
switch char(kind)
    case 'clean'
    case 'dust'
        count=round((65+45*rand(rs))*severity);
        for j=1:count
            x=16+224*rand(rs); y=16+224*rand(rs); radius=(2+6*rand(rs))*sqrt(severity);
            spot=(xx-x).^2+(yy-y).^2<radius^2;
            alpha=(0.5+0.4*rand(rs)); tone=0.45+0.5*rand(rs);
            D(spot)=(1-alpha)*D(spot)+alpha*tone;mask=mask|spot;
        end
    case 'occlusion'
        x=45+150*rand(rs);y=45+150*rand(rs);a=(30+35*rand(rs))*severity;b=(24+35*rand(rs))*severity;
        mask=((xx-x)/a).^2+((yy-y)/b).^2<1;
        texture=0.02*randn(rs,size(I));tone=0.5+0.4*rand(rs);
        D(mask)=tone+texture(mask);
    case 'blur'
        % Spatially local loss of focus with a smooth blend boundary.
        x=55+140*rand(rs);y=55+140*rand(rs);radius=(50+35*rand(rs))*severity;
        dist=hypot(xx-x,yy-y);alpha=min(max((radius+8-dist)/16,0),1);
        B=imgaussfilt(I,(1.8+1.8*rand(rs))*severity);
        D=(1-alpha).*I+alpha.*B;mask=alpha>0.5;
    otherwise
        error('Fingerprint:Kind','未知扰动类型。');
end
D=min(max(D,0),1);
end
