function I=readProjectImage(path)
info=imfinfo(path);assert(info(1).Width*info(1).Height<=30e6,'图片不得超过3000万像素。');
[I,map,alpha]=imread(path);
if ~isempty(map),I=ind2rgb(I,map);end
I=im2double(I);
if ~isempty(alpha)
    a=im2double(alpha);I=I.*a+(1-a);
end
if max(size(I,1),size(I,2))>1600,I=imresize(I,1600/max(size(I,1),size(I,2)));end
I=im2uint8(I);
end
