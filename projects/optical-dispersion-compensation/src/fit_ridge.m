function model = fit_ridge(X,Y,lambda)
% FIT_RIDGE Supervised multi-output regression; preprocessing on train only.
% J=||ZW-Y||_F^2/N + lambda*||W(1:end-1,:)||_F^2.
model.mu=mean(X,1); model.sigma=std(X,0,1);
model.sigma(model.sigma<1e-12)=1;
Z=[(X-model.mu)./model.sigma ones(size(X,1),1)];
R=eye(size(Z,2)); R(end,end)=0; % intercept not penalized
model.W=(Z.'*Z/size(Z,1)+lambda*R)\(Z.'*Y/size(Z,1));
model.lambda=lambda;
end
