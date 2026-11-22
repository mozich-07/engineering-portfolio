function results = run_all(outputRoot)
% RUN_ALL Rebuild the dataset, train, select on validation, then test once.
% With no argument outputs to ../data and ../results.
codeDir=fileparts(mfilename('fullpath')); addpath(codeDir);
if nargin<1, outputRoot=fileparts(codeDir); end
dataDir=fullfile(outputRoot,'data'); resultDir=fullfile(outputRoot,'results');
if ~exist(dataDir,'dir'), mkdir(dataDir); end
if ~exist(resultDir,'dir'), mkdir(resultDir); end
c=fiber_config(); tic;
fprintf('1/5 Generating independent train and validation blocks...\n');
train=make_blocks(c,c.trainBlocks,c.trainSnr,c.lengthKm,c.trainSeed,'train');
val=make_blocks(c,c.valBlocks,c.trainSnr,c.lengthKm,c.valSeed,'validation');
save(fullfile(dataDir,'train.mat'),'train','c','-v7');
save(fullfile(dataDir,'validation.mat'),'val','c','-v7');
fprintf('2/5 Training and selecting 30 candidates using validation NMSE...\n');
[model,search,curve]=train_equalizer(train,val,c);
save(fullfile(resultDir,'trained_model.mat'),'model','c','-v7');
writetable(search,fullfile(resultDir,'hyperparameter_search.csv'));
writetable(curve,fullfile(resultDir,'learning_curve.csv'));
fprintf('Selected K=%d, lambda=%g, validation NMSE=%g\n',model.K,model.lambda,model.validationNMSE);
fprintf('3/5 Evaluating frozen model on independent test blocks...\n');
test=struct([]); summary=table(); perBlock=table();
for s=1:numel(c.testSnrs)
    blocks=make_blocks(c,c.testBlocks,c.testSnrs(s),c.lengthKm,c.testSeed+s*1000,'test');
    test=[test blocks]; %#ok<AGROW>
    [s1,b1,e1]=evaluate_blocks(blocks,model,c); summary=[summary;s1]; perBlock=[perBlock;b1]; %#ok<AGROW>
    if c.testSnrs(s)==18, example=e1; end
end
save(fullfile(dataDir,'test.mat'),'test','c','-v7');
fprintf('4/5 Auditing unseen channel lengths without retraining...\n');
shift=struct([]); generalization=table();
for L=[40 120]
    blocks=make_blocks(c,c.testBlocks,18,L,50000+L*100,'channel_shift');
    shift=[shift blocks]; %#ok<AGROW>
    s1=evaluate_blocks(blocks,model,c); generalization=[generalization;s1]; %#ok<AGROW>
end
save(fullfile(dataDir,'channel_shift.mat'),'shift','c','-v7');
manifest={}; groups={train,val,test,shift};
for g=1:numel(groups)
    for b=groups{g}
        manifest(end+1,:)={b.split,b.seed,b.lengthKm,b.snrDb,c.nSymbols,numel(b.tx),4*c.nSymbols}; %#ok<AGROW>
    end
end
writetable(cell2table(manifest,'VariableNames',{'Split','Seed','LengthKm','SNRdB','ValidSymbols','StoredSymbols','ValidBits'}),fullfile(dataDir,'block_manifest.csv'));
% Small transparent CSV sample, not an alternative random split.
b=train(1); ix=c.guard+(1:c.nSymbols);
sample=table(ix.',real(b.tx(ix)),imag(b.tx(ix)),real(b.rx(ix)),imag(b.rx(ix)), ...
    b.bits(ix,1),b.bits(ix,2),b.bits(ix,3),b.bits(ix,4), ...
    'VariableNames',{'StoredIndex','TxI','TxQ','RxI','RxQ','Bit1','Bit2','Bit3','Bit4'});
writetable(sample,fullfile(dataDir,'train_block_10001_sample.csv'));
writetable(summary,fullfile(resultDir,'test_metrics.csv'));
writetable(perBlock,fullfile(resultDir,'test_per_block.csv'));
writetable(generalization,fullfile(resultDir,'channel_shift_metrics.csv'));
runtimeSeconds=toc;
results=struct('config',c,'model',model,'search',search,'curve',curve,'summary',summary, ...
    'generalization',generalization,'example',example,'runtimeSeconds',runtimeSeconds);
save(fullfile(resultDir,'results.mat'),'results','-v7');
js=struct('config',c,'selectedWindow',model.K,'selectedLambda',model.lambda, ...
    'runtimeSeconds',runtimeSeconds,'matlabVersion',version,'summary',table2struct(summary), ...
    'generalization',table2struct(generalization),'search',table2struct(search),'learningCurve',table2struct(curve));
fid=fopen(fullfile(resultDir,'experiment_summary.json'),'w','n','UTF-8');
fprintf(fid,'%s',jsonencode(js,'PrettyPrint',true)); fclose(fid);
fprintf('5/5 Rendering figures...\n'); render_results(results,resultDir);
fprintf('COMPLETE: %.1f seconds. Output: %s\n',runtimeSeconds,outputRoot);
disp(summary(summary.SNRdB==18,:));
end
