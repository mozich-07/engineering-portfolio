function z = predict_ridge(model,X)
% PREDICT_RIDGE No transmitted bits or test labels enter inference.
Y=[(X-model.mu)./model.sigma ones(size(X,1),1)]*model.W;
z=Y(:,1)+1i*Y(:,2);
end
