function net=fx_backbone()
% Construct from locally stored official MathWorks parameters. No download.
c=fx_config();addpath(fullfile(c.root,'third_party','resnet18'));
s=load(fullfile(c.models,'pretrained','resnet18Params.mat'),'params');
g=resnet18Layers;
for i=1:numel(g.Layers)
 layer=g.Layers(i); p=s.params.(layer.Name);
 if ~isempty(p),for field=string(fieldnames(p))', layer.(field)=p.(field); end,end
 g=replaceLayer(g,layer.Name,layer);
end
net=assembleNetwork(g);
end
