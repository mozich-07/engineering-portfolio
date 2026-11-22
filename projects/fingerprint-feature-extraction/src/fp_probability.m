function p = fp_probability(X,model)
Z=(X-model.mu)./model.sigma;
v=[ones(size(Z,1),1),Z]*model.weights;
p=1./(1+exp(-max(min(v,35),-35)));
end
