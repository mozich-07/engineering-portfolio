function model = train_project()
% TRAIN_PROJECT CPU supervised ridge regression; validation never fits beta.
c=setup_project(); if ~isfile(c.manifestPath), prepare_data(); end
M=readtable(c.manifestPath,'TextType','string');
T=M(M.Split=="train",:); V=M(M.Split=="val",:);
assert(isempty(intersect(T.SourceID,V.SourceID)),'RestoreLab:Leakage','训练验证源图重叠。');
ticTrain=tic; n=0; sx=zeros(1,52); sxx=zeros(52); sy=0; sxy=zeros(52,1);
sampleStream=RandStream('mt19937ar','Seed',c.seed+50);
fprintf('Training residual ridge model on %d source images ...\n',height(T));
for i=1:height(T)
    I=restorelab.gray(restorelab.read_image(fullfile(c.root,T.RelativePath(i))));
    interior=false(size(I)); interior(13:end-12,13:end-12)=true; pool=find(interior);
    if T.Domain(i)=="natural", take=c.naturalPixels; else, take=c.trainPixels; end
    for j=1:numel(c.cases)
        for q=1:numel(c.noiseLevels)
            sig=c.noiseLevels(q); seed=c.seed+100000+i*100+j*10+q;
            B=restorelab.degrade(I,c.cases(j),sig,seed);
            W=restorelab.wiener_restore(B,c.cases(j),sig);
            F=restorelab.features(B,W); target=I(:)-W(:);
            pick=pool(randperm(sampleStream,numel(pool),min(take,numel(pool))));
            X=F(pick,:); y=target(pick);
            n=n+numel(y); sx=sx+sum(X,1); sxx=sxx+X'*X;
            sy=sy+sum(y); sxy=sxy+X'*y;
        end
    end
    if mod(i,6)==0 || i==height(T), fprintf('  train sources %d/%d\n',i,height(T)); end
end
mu=sx/n; scale=sqrt(max(diag(sxx)'/n-mu.^2,1e-10));
C=(sxx/n-mu'*mu)./(scale'*scale); d=(sxy/n-mu'*sy/n)./scale';
models=cell(1,numel(c.lambdas));
for l=1:numel(c.lambdas)
    models{l}=struct('mu',mu,'scale',scale,'beta',(C+c.lambdas(l)*eye(52))\d, ...
        'bias',sy/n,'lambda',c.lambdas(l));
end
% Compare lambda and residual blend on validation source images only.
scores=zeros(numel(c.lambdas),numel(c.blends)); count=0;
fprintf('Validation grid: %d lambda values x %d blend values ...\n',numel(c.lambdas),numel(c.blends));
for i=1:height(V)
    I=restorelab.gray(restorelab.read_image(fullfile(c.root,V.RelativePath(i))));
    for j=1:numel(c.cases)
        for q=1:numel(c.noiseLevels)
            sig=c.noiseLevels(q); B=restorelab.degrade(I,c.cases(j),sig,c.seed+200000+i*100+j*10+q);
            W=restorelab.wiener_restore(B,c.cases(j),sig); Z=(restorelab.features(B,W)-mu)./scale;
            for l=1:numel(models)
                r=reshape(Z*models{l}.beta+models{l}.bias,size(I)); r=min(max(r,-0.2),0.2);
                for b=1:numel(c.blends)
                    R=restorelab.clip(W+c.blends(b)*r);
                    e=R(13:end-12,13:end-12)-I(13:end-12,13:end-12);
                    scores(l,b)=scores(l,b)+10*log10(1/mean(e(:).^2));
                end
            end
            count=count+1;
        end
    end
end
scores=scores/count; [~,best]=max(scores(:)); [li,bi]=ind2sub(size(scores),best);
model=models{li}; model.blend=c.blends(bi); model.version='ridge-residual-v1';
sharpScores=zeros(size(c.sharpAmounts));
for i=1:height(V)
    I=restorelab.gray(restorelab.read_image(fullfile(c.root,V.RelativePath(i))));
    for j=1:numel(c.cases)
        for q=1:numel(c.noiseLevels)
            sig=c.noiseLevels(q); B=restorelab.degrade(I,c.cases(j),sig,c.seed+200000+i*100+j*10+q);
            W=restorelab.wiener_restore(B,c.cases(j),sig); R=restorelab.apply_model(B,W,model);
            for a=1:numel(c.sharpAmounts)
                S=restorelab.sharpen(R,c.sharpAmounts(a)); e=S(13:end-12,13:end-12)-I(13:end-12,13:end-12);
                sharpScores(a)=sharpScores(a)+10*log10(1/mean(e(:).^2));
            end
        end
    end
end
sharpScores=sharpScores/count; [~,ai]=max(sharpScores); model.sharpAmount=c.sharpAmounts(ai);
model.trainSources=cellstr(T.SourceID); model.validationSources=cellstr(V.SourceID);
model.trainSamples=n; model.seed=c.seed; model.validationPSNR=scores(li,bi);
model.trainingSeconds=toc(ticTrain); model.matlabVersion=version;
model.trainingScope='Grayscale supervised residual regression, known/assumed PSF; colour uses the same model per channel.';
model.trainingCases=c.cases; model.noiseLevels=c.noiseLevels;
save(c.modelPath,'model');
info=rmfield(model,{'mu','scale','beta'});
fid=fopen(fullfile(c.root,'models','model_info.json'),'w','n','UTF-8');
fwrite(fid,jsonencode(info,'PrettyPrint',true),'char'); fclose(fid);
grid={};
for l=1:numel(c.lambdas), for b=1:numel(c.blends)
    grid(end+1,:)={c.lambdas(l),c.blends(b),scores(l,b)}; %#ok<AGROW>
end, end
writetable(cell2table(grid,'VariableNames',{'Lambda','Blend','ValidationMeanPSNR'}),fullfile(c.root,'results','validation_grid.csv'));
writetable(table(c.sharpAmounts',sharpScores','VariableNames',{'Amount','ValidationMeanPSNR'}),fullfile(c.root,'results','sharpen_validation.csv'));
fprintf('Saved model: lambda=%g, blend=%.2f, sharp=%.2f, samples=%d, time=%.1fs\n',model.lambda,model.blend,model.sharpAmount,n,model.trainingSeconds);
end
