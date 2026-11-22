function q = paired_quality(image,reference)
% One evaluation convention: exported uint8 RGB, PSNR RGB, SSIM grayscale.
X=im2double(im2uint8(image));Y=im2double(im2uint8(reference));
assert(isequal(size(X),size(Y)),'Dehaze:ReferenceSize','图像尺寸不匹配');
q=struct('psnr',psnr(X,Y),'ssim',ssim(rgb2gray(X),rgb2gray(Y)), ...
    'mae',mean(abs(X-Y),'all'),'clipped',mean(any(X<=0|X>=1,3),'all'));
end
