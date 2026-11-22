function summary = fp_train(root)
% Full reproducible supervised learning. No test data are used for selection.
if nargin<1, root=fileparts(fileparts(mfilename('fullpath'))); end
out=fullfile(root,'results');if ~isfolder(out),mkdir(out);end
rng(20261021,'twister');
files=dir(fullfile(root,'data','original','*.bmp'));n=numel(files);
assert(n==240,'Expected the documented 240-subject subset.');
order=randperm(n); splits=repmat("test",n,1);splits(order(1:144))="train";splits(order(145:192))="validation";
kinds=["clean","dust","occlusion","blur"];
X=[];Y=[];group=[];split=[];casefile=strings(0);patchid=[];kindcol=strings(0);
manifest=cell(0,7); caseidx=0;
fprintf('Build 960 cases from 240 subjects.\n');
for i=1:n
    I=fp_read(fullfile(files(i).folder,files(i).name));sid=str2double(erase(files(i).name,'.bmp'));
    foreground=imgaussfilt(I,3)<0.93;
    for j=1:4
        caseidx=caseidx+1; seed=sid*100+j;[D,M]=fp_degrade(I,kinds(j),seed);
        stem=sprintf('%03d_%s',sid,kinds(j));rel="data/cases/"+stem+".png";
        imwrite(D,fullfile(root,rel));imwrite(M,fullfile(root,'data','cases',[stem '_mask.png']));
        [F,boxes,features]=fp_features(D);valid=false(64,1);labels=false(64,1);
        for b=1:64
            c=boxes(b,1);r=boxes(b,2);roi=foreground(r:r+31,c:c+31);m=M(r:r+31,c:c+31);
            cov=mean(m(:));valid(b)=mean(roi(:))>0.65 && (cov<0.02 || cov>0.25);
            labels(b)=cov>0.25;
        end
        ids=find(valid);
        % Training balanced by class below; all eligible validation/test blocks retained.
        X=[X;F(ids,:)];Y=[Y;labels(ids)];group=[group;repmat(sid,numel(ids),1)]; %#ok<AGROW>
        split=[split;repmat(splits(i),numel(ids),1)];casefile=[casefile;repmat(rel,numel(ids),1)]; %#ok<AGROW>
        patchid=[patchid;ids];kindcol=[kindcol;repmat(kinds(j),numel(ids),1)]; %#ok<AGROW>
        manifest(end+1,:)={sid,char(splits(i)),char(kinds(j)),char(rel),seed,nnz(M)/numel(M),'synthetic variant; clean=original normalized'}; %#ok<AGROW>
    end
    if mod(i,40)==0,fprintf('Prepared %d/240 subjects\n',i);end
end
T=cell2table(manifest,'VariableNames',{'subject','split','kind','file','seed','affectedFraction','provenance'});
writetable(T,fullfile(out,'case_manifest.csv'),'Encoding','UTF-8');
tr=find(split=="train");va=split=="validation";te=split=="test";
neg=tr(Y(tr)==0);pos=tr(Y(tr)==1);nkeep=min([numel(pos),numel(neg),5000]);
tr=[neg(randperm(numel(neg),nkeep));pos(randperm(numel(pos),nkeep))];
mu=mean(X(tr,:));sigma=std(X(tr,:));sigma(sigma<1e-6)=1;
Z=[ones(numel(tr),1),(X(tr,:)-mu)./sigma];yv=Y(tr);
lambdas=[0.0001 0.001 0.01 0.1];thresholds=0.25:0.05:0.75;
best=-inf;records=[];curves=cell(4,1);
for l=1:4
    w=zeros(size(Z,2),1);loss=zeros(400,1);lambda=lambdas(l);
    for epoch=1:400
        v=max(min(Z*w,35),-35);p=1./(1+exp(-v));
        loss(epoch)=mean(log1p(exp(v))-yv.*v)+lambda/2*sum(w(2:end).^2);
        grad=Z'*(p-yv)/numel(yv)+lambda*[0;w(2:end)];w=w-0.15*grad;
    end
    candidate=struct('mu',mu,'sigma',sigma,'weights',w,'lambda',lambda,'featureNames',{features},'blockSize',32);
    pv=fp_probability(X(va,:),candidate);curves{l}=loss;
    for threshold=thresholds
        mm=fp_metrics(Y(va),pv>=threshold);records(end+1,:)=[lambda threshold mm.accuracy mm.macroF1 mm.recall]; %#ok<AGROW>
        if mm.macroF1>best
            best=mm.macroF1;model=candidate;model.threshold=threshold;model.validation=mm;selected=l;
        end
    end
    fprintf('lambda=%g loss %.4f -> %.4f\n',lambda,loss(1),loss(end));
end
% Coherence-only baseline threshold is selected on validation, independently.
bestBase=-inf;for th=0.05:0.05:0.95
    b=fp_metrics(Y(va),X(va,7)<th);
    if b.macroF1>bestBase,bestBase=b.macroF1;baseThreshold=th;end
end
model.seed=20261021;model.epochs=400;model.trainPerClass=nkeep;
model.labelDefinition='0: unaffected base fingerprint block; 1: synthetic affected footprint >25%; foreground >65%; excludes 2-25% boundary blocks';
model.note='Synthetic degradation classifier, not calibrated forensic usability or identity recognition.';
model.test=fp_metrics(Y(te),fp_probability(X(te,:),model)>=model.threshold);
model.baseline=fp_metrics(Y(te),X(te,7)<baseThreshold);model.baselineThreshold=baseThreshold;
save(fullfile(root,'models','quality_model.mat'),'model');
save(fullfile(out,'training_data.mat'),'X','Y','group','split','casefile','patchid','kindcol','tr','curves','selected');
writetable(array2table(records,'VariableNames',{'lambda','threshold','accuracy','macroF1','recall'}),fullfile(out,'validation_search.csv'));
writetable(table((1:400)',curves{selected},'VariableNames',{'epoch','trainObjective'}),fullfile(out,'learning_curve.csv'));
P=fp_probability(X,model);Pbase=X(:,7)<baseThreshold;
pred=table(group,split,casefile,patchid,kindcol,Y,P,P>=model.threshold,Pbase,'VariableNames',{'subject','split','file','patch','kind','target','damageScore','prediction','baseline'});
writetable(pred,fullfile(out,'patch_predictions.csv'),'Encoding','UTF-8');
summary=struct('seed',20261021,'subjects',240,'splitSubjects',[144 48 48],'images',960, ...
    'eligiblePatches',size(X,1),'fittedPatches',numel(tr),'validationPatches',nnz(va),'testPatches',nnz(te), ...
    'lambda',model.lambda,'threshold',model.threshold,'validation',model.validation,'test',model.test, ...
    'baseline',model.baseline,'baselineThreshold',baseThreshold,'firstLoss',curves{selected}(1),'lastLoss',curves{selected}(end));
fid=fopen(fullfile(out,'metrics.json'),'w','n','UTF-8');fprintf(fid,'%s',jsonencode(summary,PrettyPrint=true));fclose(fid);
f=figure('Visible','off','Color','w','Position',[50 50 1000 400]);
tiledlayout(1,2);nexttile;plot(1:400,curves{selected},'LineWidth',2);xlabel('迭代次数');ylabel('训练目标');title('逻辑回归真实训练记录');grid on;
nexttile;imagesc(model.test.confusion);axis square;colorbar;xticks(1:2);yticks(1:2);xticklabels({'未扰动','受扰动'});yticklabels({'未扰动','受扰动'});xlabel('预测');ylabel('标签');title('独立测试集 混淆矩阵');
for a=1:2,for b=1:2,text(b,a,num2str(model.test.confusion(a,b)),'HorizontalAlignment','center','Color','r','FontSize',16);end,end
exportgraphics(f,fullfile(out,'training_summary.png'),'Resolution',160);close(f);
fprintf('TEST macroF1=%.4f, baseline=%.4f\n',model.test.macroF1,model.baseline.macroF1);
end
