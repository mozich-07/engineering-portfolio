function model=fx_linear(X,y,lambda)
% Train-only standardization. One-vs-all linear SVM, 102 real learned classifiers.
model.mu=mean(X,1);model.sigma=max(std(X,0,1),.02);
Z=(X-model.mu)./model.sigma;
learner=templateLinear('Learner','svm','Lambda',lambda,'Solver','dual','Regularization','ridge');
model.classifier=fitcecoc(Z,y,'Learners',learner,'Coding','onevsall','ClassNames',(1:102)','Prior','uniform');
model.lambda=lambda;
end
