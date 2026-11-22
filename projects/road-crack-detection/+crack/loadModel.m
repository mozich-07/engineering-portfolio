function [model,p] = loadModel(root)
if nargin<1, root=setup_project; end
path=fullfile(root,'models','pixel_forest.mat');
if ~isfile(path), error('crack:Model','缺少模型。请在项目根目录运行 train_project。'); end
s=load(path,'model','p'); model=s.model; p=s.p;
end
