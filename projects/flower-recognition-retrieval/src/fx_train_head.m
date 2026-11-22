function [net,info]=fx_train_head(base,D,T,out)
% Low-cost transfer learning: frozen GitHub ResNet18, train a new 102-way head.
% Cached embeddings avoid repeatedly evaluating the frozen convolutions.
c=fx_config();rng(c.seed);tr=T.Split=="train";va=T.Split=="validation";
mu=mean(D(tr,:),1);sigma=max(std(D(tr,:),0,1),.02);Z=(D-mu)./sigma;
Y=categorical(T.Label,1:102,cellstr(compose('c%03d',1:102)));
counts=accumarray(T.Label(tr),1,[102 1]);weights=1./counts;weights=weights/mean(weights);
layers=[featureInputLayer(512,'Normalization','none','Name','features')
 dropoutLayer(.2,'Name','head_dropout')
 fullyConnectedLayer(102,'Name','flower_head')
 softmaxLayer('Name','prob')
 classificationLayer('Name','flower_output','Classes',categorical(compose('c%03d',1:102)),'ClassWeights',weights')];
opts=trainingOptions('adam','InitialLearnRate',c.learningRate,'MaxEpochs',c.maxEpochs,'MiniBatchSize',c.batchSize,'Shuffle','every-epoch', ...
 'ValidationData',{Z(va,:),Y(va)},'ValidationFrequency',max(1,floor(sum(tr)/64)),'ValidationPatience',4, ...
 'OutputNetwork','best-validation-loss','L2Regularization',.0001,'ExecutionEnvironment',c.headEnvironment, ...
 'Verbose',true,'VerboseFrequency',100,'Plots','none','OutputFcn',@progress);
[head,info]=trainNetwork(Z(tr,:),Y(tr),layers,opts);
% Fold train-only standardization into the final FC layer for one-image inference.
% Recreate the FC layer: the trained vector head retains a 0-spatial-dimension
% input contract, while pool5 produces a 1-by-1 spatial CNN activation.
fc=fullyConnectedLayer(102,'Name','flower_head');
fc.Weights=head.Layers(3).Weights./sigma;fc.Bias=head.Layers(3).Bias-fc.Weights*mu';
g=layerGraph(base);g=replaceLayer(g,'fc1000',fc);
output=classificationLayer('Name','flower_output','Classes',head.Layers(end).Classes);
g=replaceLayer(g,'ClassificationLayer_predictions',output);net=assembleNetwork(g);
reference=predict(head,Z(1:8,:));folded=fx_head_scores(net,D(1:8,:));
assert(max(abs(double(reference(:))-folded(:)))<1e-4,'分类头标准化折叠不一致。');
save(fullfile(out,'network.mat'),'net','head','info','mu','sigma','-v7.3');
 function stop=progress(s)
  stop=isfile(fullfile(c.experiments,'STOP_REQUESTED'));
  if isfield(s,'Iteration')
   writelines(jsonencode(struct('stage','training classification head','iteration',s.Iteration,'state',s.State)),fullfile(c.experiments,'progress.json'));drawnow limitrate;
  end
 end
end
