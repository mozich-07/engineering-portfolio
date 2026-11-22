function e=fx_ece(P,y)
[p,k]=max(P,[],2);e=0;
for b=1:10,ids=p>(b-1)/10 & p<=b/10;if any(ids),e=e+mean(ids)*abs(mean(p(ids))-mean(k(ids)==y(ids)));end,end
end
