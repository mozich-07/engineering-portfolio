function X = features(B,W)
% 52 translation-invariant local predictors; no clean image used.
P=im2col(padarray(W,[2 2],'symmetric'),[5 5],'sliding')';
Q=im2col(padarray(B,[2 2],'symmetric'),[5 5],'sliding')';
center=13; wc=W(:); bc=B(:);
idx=[1:12 14:25];
X=[P(:,idx)-wc,Q(:,idx)-bc,wc-bc, ...
    std(P,0,2),std(Q,0,2),abs(wc-bc)];
end
