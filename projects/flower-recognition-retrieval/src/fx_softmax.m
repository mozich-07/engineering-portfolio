function P=fx_softmax(S)
S=S-max(S,[],2);P=exp(S);P=P./sum(P,2);
end
