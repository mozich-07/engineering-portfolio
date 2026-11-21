function m = metrics(pred,truth)
% 严格逐像素评价，不进行容差膨胀；背景占比大，不以 Accuracy 为主指标。
pred=logical(pred); truth=logical(truth);
assert(isequal(size(pred),size(truth)),'预测与标注尺寸不一致。');
tp=nnz(pred & truth); fp=nnz(pred & ~truth); fn=nnz(~pred & truth);
if tp+fp==0, precision=double(nnz(truth)==0); else, precision=tp/(tp+fp); end
if tp+fn==0, recall=1; else, recall=tp/(tp+fn); end
if 2*tp+fp+fn==0, f1=1; iou=1; else, f1=2*tp/(2*tp+fp+fn); iou=tp/(tp+fp+fn); end
m=struct('TP',tp,'FP',fp,'FN',fn,'Precision',precision,'Recall',recall,'F1',f1,'IoU',iou);
end
