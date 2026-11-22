function r = analyze(input,method,p,model)
if nargin<2, method='fusion'; end
if nargin<3, p=crack.defaults; end
start=tic;
[rgb,gray]=crack.readImage(input,p.maxDimension);
if strcmp(method,'fusion')
    [X,maps]=crack.features(gray,p);
else
    g=imgaussfilt(gray,0.65);
    maps=struct('gray',gray,'enhanced',adapthisteq(g,'ClipLimit',0.008), ...
        'dark',max(imgaussfilt(g,12)-g,0),'ridge',zeros(size(g),'single'), ...
        'blackhat',imbothat(g,strel('disk',7,0)),'localStd',stdfilt(g,true(9)));
end
switch char(method)
    case 'otsu'
        % 同样使用轻度平滑，暗像素为裂缝。
        score=single(imgaussfilt(gray,0.65)<graythresh(imgaussfilt(gray,0.65)));
        mask=bwareaopen(logical(score),p.minArea,8);
    case 'morphology'
        score=maps.blackhat;
        mask=bwareaopen(score>max(graythresh(score),0.015),p.minArea,8);
        if p.closeRadius>0, mask=imclose(mask,strel('disk',p.closeRadius,0)); end
    case 'fusion'
        if nargin<4 || isempty(model), error('crack:Model','请先运行 train_project 生成分类模型。'); end
        if model.featureVersion~=p.featureVersion, error('crack:Version','模型与特征版本不匹配，请重新训练。'); end
        [~,s]=predict(model.classifier,X);
        positive=find(model.classifier.ClassNames==1,1);
        score=reshape(single(s(:,positive)),size(gray));
        mask=crack.postprocess(score,p);
    otherwise
        error('crack:Method','未知算法。');
end
q=crack.quantify(mask,p.mmPerPixel);
r=struct('rgb',rgb,'maps',maps,'score',score,'mask',mask,'quant',q, ...
    'overlay',crack.overlay(rgb,mask),'method',char(method),'seconds',toc(start),'parameters',p);
end
