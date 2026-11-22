function out = overlay(rgb,mask,color)
if nargin<3, color=[1 0.22 0.12]; end
out=im2double(rgb); alpha=0.48;
for k=1:3
    plane=out(:,:,k); plane(mask)=(1-alpha)*plane(mask)+alpha*color(k); out(:,:,k)=plane;
end
out=im2uint8(out);
end
