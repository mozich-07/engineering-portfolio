function out = process(B,p,noiseSigma,model,amount,reference)
if nargin<5 || isempty(amount), amount=model.sharpAmount; end
if nargin<6, reference=[]; end
validateattributes(B,{'double'},{'real','nonempty','finite','>=',0,'<=',1});
validateattributes(noiseSigma,{'numeric'},{'scalar','real','finite','>=',0,'<=',0.1});
assert(min(size(B,1),size(B,2))>=32,'RestoreLab:Input','图像尺寸至少 32×32。');
t=tic;
out.input=B;
out.sharpenOnly=restorelab.sharpen(B,0.5);
out.wiener=restorelab.wiener_restore(B,p,noiseSigma);
out.learned=restorelab.apply_model(B,out.wiener,model);
out.final=restorelab.sharpen(out.learned,amount);
out.seconds=toc(t);
out.params=p; out.noiseSigma=noiseSigma; out.sharpAmount=amount;
out.hasReference=~isempty(reference);
out.modelVersion=model.version;
methods={'input','sharpenOnly','wiener','learned','final'};
rows=cell(numel(methods),6);
for k=1:numel(methods)
    m=restorelab.metrics(out.(methods{k}),reference,12);
    rows(k,:)={methods{k},m.PSNR,m.SSIM,m.RMSE,m.GradientEnergy,m.SaturationRate};
end
out.metrics=cell2table(rows,'VariableNames',{'Method','PSNR','SSIM','RMSE','GradientEnergy','SaturationRate'});
end
