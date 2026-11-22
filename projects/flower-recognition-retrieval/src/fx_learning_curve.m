function fx_learning_curve(X,y,V,vy,folder)
% Fixed validation set, nested stratified train subsets; descriptive single-seed curve.
rows=[];
for seed=7
 rng(seed);orders=cell(102,1);for k=1:102,ids=find(y==k);orders{k}=ids(randperm(numel(ids)));end
 for fraction=[.25 .5 1]
  ids=[];for k=1:102,ids=[ids;orders{k}(1:max(2,floor(fraction*numel(orders{k}))))];end %#ok<AGROW>
  m=fx_linear(X(ids,:),y(ids),.001);p=fx_score(m,V);a=fx_metrics(vy,p,102);
  rows(end+1,:)=[seed fraction numel(ids) a.accuracy a.macroF1]; %#ok<AGROW>
 end
end
writetable(array2table(rows,'VariableNames',{'Seed','Fraction','TrainImages','ValidationAccuracy','ValidationMacroF1'}),fullfile(folder,'learning_curve.csv'));
end
