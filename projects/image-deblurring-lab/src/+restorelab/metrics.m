function m = metrics(I,reference,border)
if nargin<3, border=0; end
G=restorelab.gray(I);
dx=diff(G,1,2); dy=diff(G,1,1);
m.GradientEnergy=mean(dx(:).^2)+mean(dy(:).^2);
m.SaturationRate=mean(I(:)<=0 | I(:)>=1);
m.PSNR=NaN; m.SSIM=NaN; m.RMSE=NaN;
if isempty(reference), return; end
assert(isequal(size(I),size(reference)),'RestoreLab:ReferenceSize','参考图必须与结果尺寸相同。');
assert(min(size(I,1),size(I,2))>2*border+10,'RestoreLab:MetricSize','裁边后尺寸过小。');
A=I(1+border:end-border,1+border:end-border,:);
T=reference(1+border:end-border,1+border:end-border,:);
e=A-T; mse=mean(e(:).^2); m.RMSE=sqrt(mse);
if mse==0, m.PSNR=Inf; else, m.PSNR=10*log10(1/mse); end
sv=zeros(1,size(A,3));
for ch=1:size(A,3), sv(ch)=ssim(A(:,:,ch),T(:,:,ch),'DynamicRange',1); end
m.SSIM=mean(sv);
end
