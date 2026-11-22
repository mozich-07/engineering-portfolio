function B = degrade(I,p,noiseSigma,seed)
validateattributes(noiseSigma,{'numeric'},{'scalar','real','finite','>=',0,'<=',0.1});
K=restorelab.make_psf(p);
% Local stream preserves user RNG; symmetric boundaries avoid wraparound.
s=RandStream('mt19937ar','Seed',seed);
B=imfilter(I,K,'conv','symmetric')+noiseSigma*randn(s,size(I));
B=restorelab.clip(B);
end
