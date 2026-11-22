function [model,search,curve] = train_equalizer(train,val,c)
% TRAIN_EQUALIZER Test data are deliberately absent from this function.
rows=[]; best=Inf; bestModel=[];
for K=c.windows
    [X,Y]=window_features(train,K,c); [V,T]=window_features(val,K,c);
    vt=T(:,1)+1i*T(:,2);
    for lambda=c.lambdas
        m=fit_ridge(X,Y,lambda); z=predict_ridge(m,V);
        nmse=mean(abs(z-vt).^2)/mean(abs(vt).^2);
        rows(end+1,:)=[K lambda nmse]; %#ok<AGROW>
        if nmse<best
            best=nmse; bestModel=m; bestModel.K=K;
        end
    end
end
search=array2table(rows,'VariableNames',{'Window','Lambda','ValidationNMSE'});
model=bestModel; model.lengthKm=c.lengthKm; model.trainSnr=c.trainSnr;
model.nTrain=c.nSymbols*numel(train); model.validationNMSE=best;
[X,Y]=window_features(train,model.K,c); [V,T]=window_features(val,model.K,c);
rng(771,'twister'); perm=randperm(size(X,1));
counts=unique([256 512 2048 8192 size(X,1)]); rows=[];
for n=counts(counts<=size(X,1))
    ix=perm(1:n); m=fit_ridge(X(ix,:),Y(ix,:),model.lambda);
    tr=Y(ix,1)+1i*Y(ix,2); vt=T(:,1)+1i*T(:,2);
    rows(end+1,:)=[n mean(abs(predict_ridge(m,X(ix,:))-tr).^2)/mean(abs(tr).^2), ...
        mean(abs(predict_ridge(m,V)-vt).^2)/mean(abs(vt).^2)]; %#ok<AGROW>
end
curve=array2table(rows,'VariableNames',{'TrainSamples','TrainNMSE','ValidationNMSE'});
end
