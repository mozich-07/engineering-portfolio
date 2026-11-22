function metrics=fx_metrics(truth,predicted,nClass)
C=accumarray([double(truth(:)),double(predicted(:))],1,[nClass nClass]);
precision=diag(C)./max(sum(C,1)',1); recall=diag(C)./max(sum(C,2),1);
f1=2*precision.*recall./max(precision+recall,eps);
metrics.confusion=C; metrics.accuracy=sum(diag(C))/sum(C(:));
metrics.macroF1=mean(f1); metrics.precision=precision; metrics.recall=recall;
metrics.f1=f1; metrics.support=sum(C,2);
end
