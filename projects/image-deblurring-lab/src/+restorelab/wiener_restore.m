function W = wiener_restore(B,p,noiseSigma)
% Adapted from Ibad-Ur-Rahman-Memon/image-deblurring-project (MIT).
% See third_party/UPSTREAM_LICENSE.txt. Original uses reference-image
% variance and circular boundaries; this version uses observed data only
% and symmetric padding, and handles each colour channel explicitly.
K=restorelab.make_psf(p);
Y=restorelab.gray(B);
signalVariance=max(var(Y(:))-noiseSigma^2,1e-4);
nsr=max(noiseSigma^2/signalVariance,1e-5);
pad=max(16,2*max(size(K)));
W=zeros(size(B));
for ch=1:size(B,3)
    P=padarray(B(:,:,ch),[pad pad],'symmetric','both');
    R=deconvwnr(P,K,nsr);
    W(:,:,ch)=R(pad+1:pad+size(B,1),pad+1:pad+size(B,2));
end
W=restorelab.clip(W);
end
