function r=fx_predict(model,source)
c=fx_config();t=tic;I=fx_read(source);assert(std(I(:))>.006,'图片缺少有效内容，请换一张照片。');
input=fx_input(I);
if strcmp(model.type,'network')
 scores=predict(model.object,input,'ExecutionEnvironment','cpu');logits=log(max(double(scores),1e-8));net=model.object;
else
 net=model.base;
 if strcmp(model.type,'handcrafted'),f=fx_features(I);else,f=activations(net,input,'pool5','OutputAs','rows','ExecutionEnvironment','cpu');end
 [~,logits]=fx_score(model.object,f);
end
p=fx_softmax(double(logits)/model.temperature);[sorted,rank]=sort(p,'descend');
e=activations(net,input,'pool5','OutputAs','rows','ExecutionEnvironment','cpu');e=e/max(norm(e),eps);
dist=max(0,2-2*single(e)*model.galleryFeatures');
% Do not return the exact query file if it is already in the gallery.
if isstring(source)||ischar(source),q=fx_sha256(source);dist(model.gallery.SHA256==q)=inf;end
[d,idx]=sort(dist);idx=idx(1:6);d=d(1:6);
r=struct('label',rank(1),'name',model.classes.Display(rank(1)),'probabilities',p,'rank',rank,'topScores',sorted, ...
 'review',sorted(1)<model.reviewThreshold,'neighbors',model.gallery(idx,:),'distances',sqrt(d(:)), ...
 'image',I,'gray',rgb2gray(I),'edge',edge(rgb2gray(imresize(I,[224 224])),'Canny'),'seconds',toc(t),'runId',model.runId);
end
