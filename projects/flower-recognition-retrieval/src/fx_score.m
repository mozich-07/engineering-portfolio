function [pred,scores]=fx_score(model,X)
[pred,scores]=predict(model.classifier,(X-model.mu)./model.sigma);
end
