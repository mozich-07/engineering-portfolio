function fx_plots(folder,model,T)
% All graphics generated directly from actual experiment records.
f=figure('Visible','off','Color','w','Position',[30 30 1100 600]);
M=model.comparison;bar([M.ValidationAccuracy M.TestAccuracy]);ylim([0 1]);xticks(1:height(M));xticklabels(M.Model);xtickangle(18);
ylabel('Accuracy');legend('Validation','Test','Location','southeast');title('Fixed candidate comparison - selected on validation Macro-F1');grid on;
exportgraphics(f,fullfile(folder,'comparison.png'),'Resolution',150);close(f);
f=figure('Visible','off','Color','w','Position',[30 30 1000 850]);imagesc(model.metrics.confusion);colorbar;axis image;xlabel('Predicted class ID');ylabel('True class ID');title('102-class held-out confusion matrix');
exportgraphics(f,fullfile(folder,'confusion.png'),'Resolution',150);close(f);
f=figure('Visible','off','Color','w','Position',[30 30 1000 500]);L=readtable(fullfile(folder,'learning_curve.csv'));
plot(100*L.Fraction,100*L.ValidationAccuracy,'o-','LineWidth',2);grid on;xlabel('Training fraction (%)');ylabel('Validation accuracy (%)');title('Frozen ResNet18 + linear SVM - fixed validation, one seed');
exportgraphics(f,fullfile(folder,'learning_curve.png'),'Resolution',150);close(f);
f=figure('Visible','off','Color','w','Position',[30 30 1100 500]);tiledlayout(1,2);
for aug=1
 a=load(fullfile(folder,'transfer_head','network.mat'),'info'); info=a.info;
 nexttile;plot(info.TrainingLoss,'Color',[.3 .6 .4]);hold on;idx=find(isfinite(info.ValidationLoss));plot(idx,info.ValidationLoss(idx),'o-');grid on;title('Frozen backbone / trained head - loss');legend('Mini-batch train','Validation');
 nexttile;plot(info.TrainingAccuracy);hold on;idx=find(isfinite(info.ValidationAccuracy));plot(idx,info.ValidationAccuracy(idx),'o-');grid on;title('Frozen backbone / trained head - accuracy');ylim([0 100]);
end
exportgraphics(f,fullfile(folder,'training_curves.png'),'Resolution',150);close(f);
f=figure('Visible','off','Color','w','Position',[30 30 900 500]);bins=0:.1:1;meanP=nan(1,10);acc=meanP;
for i=1:10,k=T.Confidence>bins(i)&T.Confidence<=bins(i+1);if any(k),meanP(i)=mean(T.Confidence(k));acc(i)=mean(T.Correct(k));end,end
plot([0 1],[0 1],'--');hold on;plot(meanP,acc,'o-','LineWidth',2);axis([0 1 0 1]);grid on;xlabel('Mean calibrated score');ylabel('Observed accuracy');title('Reliability diagram on held-out test');
exportgraphics(f,fullfile(folder,'calibration.png'),'Resolution',150);close(f);
end
