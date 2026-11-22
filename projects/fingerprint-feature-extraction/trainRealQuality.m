function trainRealQuality(root)
% Supervised regression to the source authors' mean opinion scores (MOS).
if nargin<1,root=fileparts(mfilename('fullpath'));end;addpath(fullfile(root,'src'));
T=readtable(fullfile(root,'sources','real_split.csv'),'TextType','string');X=zeros(height(T),64);
for k=1:height(T),I=imread(fullfile(root,T.file(k)));[X(k,:),featureNames]=fp_real_features(I);end
tr=T.split=="train";va=T.split=="validation";te=T.split=="test";y=T.mos;
assert(isempty(intersect(T.group(tr),T.group(te)))&&isempty(intersect(T.group(va),T.group(te))));
rng(20261022,'twister');records=[];best=Inf;models={};
for leaf=[3 8 16]
    for trees=[50 100]
        learner=templateTree('MinLeafSize',leaf,'NumVariablesToSample',8);
        q=fitrensemble(X(tr,:),y(tr),'Method','Bag','NumLearningCycles',trees,'Learners',learner);
        pred=min(100,max(0,predict(q,X(va,:))));mae=mean(abs(pred-y(va)));
        records=[records;leaf trees mae];models{end+1}=q; %#ok<AGROW>
        fprintf('leaf %d trees %d validation MAE %.4f\n',leaf,trees,mae);
        if mae<best,best=mae;realQuality=q;config=struct('leaf',leaf,'trees',trees);end
    end
end
prediction=min(100,max(0,predict(realQuality,X)));baseline=repmat(mean(y(tr)),size(y));
T.prediction=prediction;T.baseline=baseline;out=fullfile(root,'results','real_quality');if ~isfolder(out),mkdir(out);end
writetable(T,fullfile(out,'predictions.csv'),'Encoding','UTF-8');
writetable(array2table(records,'VariableNames',{'MinLeafSize','Trees','ValidationMAE'}),fullfile(out,'validation_search.csv'));
treeCounts=(1:5:config.trees)';if treeCounts(end)~=config.trees,treeCounts(end+1)=config.trees;end
trainMAE=zeros(size(treeCounts));valMAE=trainMAE;
for k=1:numel(treeCounts)
    p=predict(realQuality,X,'Learners',1:treeCounts(k));trainMAE(k)=mean(abs(p(tr)-y(tr)));valMAE(k)=mean(abs(p(va)-y(va)));
end
writetable(table(treeCounts,trainMAE,valMAE),fullfile(out,'learning_curve.csv'));
metrics=struct('trainImages',nnz(tr),'validationImages',nnz(va),'testImages',nnz(te),'features',size(X,2),'seed',20261022,'selected',config,'validationMAE',best, ...
    'testMAE',mean(abs(prediction(te)-y(te))),'baselineMAE',mean(abs(baseline(te)-y(te))),'testRMSE',sqrt(mean((prediction(te)-y(te)).^2)), ...
    'testPearson',corr(prediction(te),y(te)),'testSpearman',corr(prediction(te),y(te),'Type','Spearman'), ...
    'note','MOS quality regression on real scene images. Image/perceptual-group split; subject IDs unavailable. Not identity accuracy or minutiae accuracy.');
save(fullfile(root,'models','real_quality_model.mat'),'realQuality','metrics','featureNames','config');
fid=fopen(fullfile(out,'metrics.json'),'w','n','UTF-8');fprintf(fid,'%s',jsonencode(metrics,PrettyPrint=true));fclose(fid);
save(fullfile(out,'training_data.mat'),'X','y','tr','va','te','featureNames');disp(metrics);
end
