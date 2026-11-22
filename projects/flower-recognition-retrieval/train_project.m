function runDir=train_project(force)
% Complete experiment; every run has its own directory. Test used after selection.
if nargin<1,force=false;end
root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'src'));c=fx_config();
if ~isfolder(c.experiments), mkdir(c.experiments); end
if ~isfolder(c.results), mkdir(c.results); end
if ~isfolder(c.models), mkdir(c.models); end
lock=fullfile(c.experiments,'RUNNING');assert(~isfile(lock),'训练正在运行，不能重复启动。');
writelines(string(datetime('now')),lock);cleanup=onCleanup(@()releaseLock(lock)); %#ok<NASGU>
stop=fullfile(c.experiments,'STOP_REQUESTED');if isfile(stop),delete(stop);end
runId=char(datetime('now','Format','yyyyMMdd_HHmmss'));runDir=fullfile(c.experiments,runId);mkdir(runDir);
diary(fullfile(runDir,'training.log'));diaryCleanup=onCleanup(@()diary('off')); %#ok<NASGU>
rng(c.seed);writelines(jsonencode(c,'PrettyPrint',true),fullfile(runDir,'configuration.json'));
[T,classes,audit]=fx_prepare(force);T=T(T.Split~="excluded",:);base=fx_backbone();[H,D]=fx_extract(T,base,force);
tr=T.Split=="train";va=T.Split=="validation";te=T.Split=="test";
rows=cell(0,5);candidates={};valScores={};
% Fixed candidates chosen before observing held-out test results.
for type=["handcrafted","deep"]
 if type=="handcrafted",X=H;grid=.001;else,X=D;grid=[.001 .01];end
 for lambda=grid
  rng(c.seed);tic;obj=fx_linear(X(tr,:),T.Label(tr),lambda);
  [pred,scores]=fx_score(obj,X(va,:));m=fx_metrics(T.Label(va),pred,102);
  name=sprintf('%s SVM lambda=%g',type,lambda);
  rows(end+1,:)={name,m.accuracy,m.macroF1,toc,char(type)}; %#ok<AGROW>
  candidates{end+1}=obj;valScores{end+1}=scores; %#ok<AGROW>
  fprintf('%s validation F1 %.4f\n',name,m.macroF1);
 end
end
% One frozen-backbone classification-head run keeps the project affordable.
for transferRun=1
 out=fullfile(runDir,'transfer_head');mkdir(out);
 tic;[net,info]=fx_train_head(base,D,T,out); %#ok<ASGLU>
 assert(~isfile(stop),'训练已停止，本次结果不发布。');
 scores=fx_head_scores(net,D(va,:));
 [~,pred]=max(scores,[],2);m=fx_metrics(T.Label(va),pred,102);
 rows(end+1,:)={'ResNet18 frozen + trained head',m.accuracy,m.macroF1,toc,'network'}; %#ok<AGROW>
 candidates{end+1}=net;valScores{end+1}=scores; %#ok<AGROW>
end
comparison=cell2table(rows,'VariableNames',{'Model','ValidationAccuracy','ValidationMacroF1','TrainSeconds','Type'});
[~,best]=max(comparison.ValidationMacroF1);writetable(comparison,fullfile(runDir,'validation_comparison.csv'));
selection=struct('index',best,'model',comparison.Model{best},'criterion','validation Macro-F1','testUsed',false);
writelines(jsonencode(selection,'PrettyPrint',true),fullfile(runDir,'selection_locked.json'));
model=struct('runId',runId,'type',comparison.Type{best},'name',comparison.Model{best},'object',candidates{best}, ...
 'classes',classes,'base',base,'audit',audit,'config',rmfield(c,{'root','data','results','models','experiments'}));
% Calibration and review threshold fitted solely on validation predictions.
S=double(valScores{best});if strcmp(model.type,'network'),S=log(max(S,1e-8));end
model.temperature=exp(fminbnd(@(z)fx_nll(S,T.Label(va),exp(z)),-4,4));
PV=fx_softmax(S/model.temperature);[conf,~]=max(PV,[],2);model.reviewThreshold=quantile(conf,.15);
% Frozen test evaluation for each fixed candidate; selection remains unchanged.
testScores=cell(numel(candidates),1);comparison.TestAccuracy=zeros(height(comparison),1);comparison.TestMacroF1=comparison.TestAccuracy;
for i=1:numel(candidates)
 if strcmp(comparison.Type{i},'network')
  testScores{i}=fx_head_scores(candidates{i},D(te,:));
 else
  if strcmp(comparison.Type{i},'handcrafted'),X=H;else,X=D;end
  [~,testScores{i}]=fx_score(candidates{i},X(te,:));
 end
 [~,pred]=max(testScores{i},[],2);m=fx_metrics(T.Label(te),pred,102);
 comparison.TestAccuracy(i)=m.accuracy;comparison.TestMacroF1(i)=m.macroF1;
end
scores=double(testScores{best});if strcmp(model.type,'network'),scores=log(max(scores,1e-8));end
P=fx_softmax(scores/model.temperature);[confidence,pred]=max(P,[],2);[~,rank]=sort(P,2,'descend');
metrics=fx_metrics(T.Label(te),pred,102);metrics.top5=mean(any(rank(:,1:5)==T.Label(te),2));
metrics.nll=fx_nll(scores,T.Label(te),model.temperature);metrics.modelName=model.name;metrics.testCount=sum(te);
metrics.accuracyCI=fx_interval(sum(pred==T.Label(te)),sum(te));
metrics.reviewCoverage=mean(confidence>=model.reviewThreshold);metrics.reviewThreshold=model.reviewThreshold;
truth=T.Label(te);metrics.acceptedAccuracy=mean(pred(confidence>=model.reviewThreshold)==truth(confidence>=model.reviewThreshold));
metrics.calibrationECE=fx_ece(P,truth);
% Retrieval uses learned representation, training gallery only, independent of class prediction.
E=D; % Every candidate uses the same frozen backbone; reuse exact cached embeddings.
E=single(E)./max(vecnorm(single(E),2,2),eps);model.galleryFeatures=E(tr,:);model.gallery=T(tr,:);
dist=max(0,2-2*E(te,:)*E(tr,:)');[~,r]=sort(dist,2,'ascend');galleryLabels=T.Label(tr);
p5=mean(galleryLabels(r(:,1:5))==truth,2);metrics.retrievalP5=mean(p5);
% Per-example records support exact metric recalculation and real error browsing.
predictions=T(te,:);predictions.Predicted=pred;predictions.Confidence=confidence;predictions.Correct=pred==truth;
predictions.Top5Correct=any(rank(:,1:5)==truth,2);predictions.NeedsReview=confidence<model.reviewThreshold;predictions.RetrievalP5=p5;
model.metrics=metrics;model.comparison=comparison;model.validationScores=S;
writetable(predictions,fullfile(runDir,'test_predictions.csv'),'Encoding','UTF-8');
writetable(comparison,fullfile(runDir,'model_comparison.csv'),'Encoding','UTF-8');
writetable(table(classes.Display,metrics.precision,metrics.recall,metrics.f1,metrics.support,'VariableNames', ...
 {'Class','Precision','Recall','F1','Support'}),fullfile(runDir,'class_metrics.csv'),'Encoding','UTF-8');
writelines(jsonencode(metrics,'PrettyPrint',true),fullfile(runDir,'metrics.json'));
fx_learning_curve(D(tr,:),T.Label(tr),D(va,:),T.Label(va),runDir);
save(fullfile(runDir,'model.mat'),'model','-v7.3');
fx_plots(runDir,model,predictions);
% Commit active pointer only after the complete model and all evidence exist.
writelines(runId,fullfile(c.models,'active_run.txt'));writelines(jsonencode(struct('stage','complete','runId',runId)),fullfile(c.experiments,'progress.json'));
fprintf('COMPLETE %s | test %.2f%% | macroF1 %.4f | retrieval %.2f%%\n',runId,100*metrics.accuracy,metrics.macroF1,100*metrics.retrievalP5);
end
function releaseLock(path),if isfile(path),delete(path);end,end
