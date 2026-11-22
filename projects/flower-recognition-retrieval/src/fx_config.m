function c=fx_config()
c.root=fileparts(fileparts(mfilename('fullpath')));
c.data=fullfile(c.root,'data','oxford102'); c.results=fullfile(c.root,'results');
c.models=fullfile(c.root,'models'); c.experiments=fullfile(c.root,'experiments');
c.seed=20261016; c.imageSize=[160 160]; c.inputSize=[224 224];
c.nClasses=102; c.featureVersion='oxford102-v2-resnet18';
c.maxEpochs=20; c.batchSize=64; c.learningRate=0.001;c.headEnvironment='cpu';
persistent executionEnvironment
if isempty(executionEnvironment)
 executionEnvironment='cpu';try,if canUseGPU,executionEnvironment='gpu';end,catch,end
end
c.environment=executionEnvironment;
end
