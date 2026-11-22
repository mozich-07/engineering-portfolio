function loss=fx_nll(S,y,temperature)
P=fx_softmax(S/temperature);loss=-mean(log(max(P(sub2ind(size(P),(1:numel(y))',y(:))),1e-12)));
end
