function mask = postprocess(score,p)
mask=score>=p.threshold;
if p.closeRadius>0, mask=imclose(mask,strel('disk',p.closeRadius,0)); end
mask=bwareaopen(mask,p.minArea,8);
end
