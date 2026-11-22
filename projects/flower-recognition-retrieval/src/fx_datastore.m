function ds=fx_datastore(T,augment)
c=fx_config(); imds=imageDatastore(cellstr(fullfile(c.root,T.Path)),'ReadFcn',@(p)im2uint8(fx_read(p)));
imds.Labels=categorical(T.Label,1:102,cellstr(compose('c%03d',1:102)));
if augment
 aug=imageDataAugmenter('RandRotation',[-20 20],'RandXReflection',true,'RandXTranslation',[-12 12], ...
  'RandYTranslation',[-12 12],'RandXScale',[.9 1.1],'RandYScale',[.9 1.1]);
 ds=augmentedImageDatastore(c.inputSize,imds,'DataAugmentation',aug);
else,ds=augmentedImageDatastore(c.inputSize,imds);end
end
