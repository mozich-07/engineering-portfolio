function summary = evaluate_project()
% EVALUATE_PROJECT Held-out source images; no hyperparameter updates here.
c=setup_project(); model=restorelab.load_model(c);
M=readtable(c.manifestPath,'TextType','string'); T=M(M.Split=="test",:);
assert(isempty(intersect(T.SourceID,string([model.trainSources;model.validationSources]))), ...
    'RestoreLab:Leakage','测试源图与训练/验证集重叠。');
rows={}; fprintf('Evaluating %d held-out source images ...\n',height(T));
for i=1:height(T)
    I=restorelab.gray(restorelab.read_image(fullfile(c.root,T.RelativePath(i))));
    for j=1:numel(c.cases)
        for q=1:numel(c.noiseLevels)
            sig=c.noiseLevels(q); seed=c.seed+300000+i*100+j*10+q;
            B=restorelab.degrade(I,c.cases(j),sig,seed);
            out=restorelab.process(B,c.cases(j),sig,model,[],I);
            for k=1:height(out.metrics)
                r=out.metrics(k,:); R=out.(r.Method{1}); mfull=restorelab.metrics(R,I,0);
                rows(end+1,:)={char(T.SourceID(i)),char(T.Domain(i)),c.cases(j).name,sig,seed, ...
                    r.Method{1},r.PSNR,r.SSIM,r.RMSE,mfull.PSNR,mfull.SSIM,out.seconds}; %#ok<AGROW>
            end
            if j==2 && q==2 && (i==1 || T.Domain(i)=="natural")
                folder=fullfile(c.root,'results','examples',char(T.SourceID(i)));
                restorelab.export_result(out,folder,I);
                make_comparison(out,I,folder,char(T.SourceID(i)));
            end
        end
    end
    fprintf('  test sources %d/%d\n',i,height(T));
end
E=cell2table(rows,'VariableNames',{'SourceID','Domain','BlurCase','NoiseSigma','Seed','Method','PSNR','SSIM','RMSE','FullPSNR','FullSSIM','PipelineSeconds'});
writetable(E,fullfile(c.root,'results','test_metrics.csv'),'Encoding','UTF-8');
methods=unique(E.Method,'stable'); summaryRows={};
for domain={'all','procedural','natural'}
    for k=1:numel(methods)
        mask=strcmp(E.Method,methods{k});
        if ~strcmp(domain{1},'all'), mask=mask & strcmp(E.Domain,domain{1}); end
        R=E(mask,:);
        summaryRows(end+1,:)={domain{1},methods{k},height(R),mean(R.PSNR),std(R.PSNR),mean(R.SSIM),mean(R.RMSE),mean(R.FullPSNR)}; %#ok<AGROW>
    end
end
summary=cell2table(summaryRows,'VariableNames',{'Domain','Method','Cases','MeanPSNR','StdPSNR','MeanSSIM','MeanRMSE','MeanFullPSNR'});
writetable(summary,fullfile(c.root,'results','summary.csv'));
% Uncertainty unit is ORIGINAL SOURCE IMAGE, not correlated degradation.
gainRows={};
for i=1:height(T)
    mask=strcmp(E.SourceID,T.SourceID(i));
    a=E.PSNR(mask & strcmp(E.Method,'learned')); b=E.PSNR(mask & strcmp(E.Method,'wiener'));
    gainRows(end+1,:)={char(T.SourceID(i)),char(T.Domain(i)),mean(a-b),mean(a>b)}; %#ok<AGROW>
end
G=cell2table(gainRows,'VariableNames',{'SourceID','Domain','LearnedMinusWienerPSNR','WinRate'});
writetable(G,fullfile(c.root,'results','source_gains.csv'));
fprintf('Evaluation complete. Metrics use grayscale, 12px interior; full-frame metrics also saved.\n'); disp(summary);
make_summary_plot(summary,c);
end

function make_comparison(out,I,folder,id)
f=figure('Visible','off','Color','w','Position',[100 100 1200 650]); clean=onCleanup(@()close(f));
tiledlayout(2,3,'Padding','compact','TileSpacing','compact');
names={'Reference','Input','Sharpen only','Wiener','Learned residual','Final'};
images={I,out.input,out.sharpenOnly,out.wiener,out.learned,out.final};
for k=1:6
    nexttile; imshow(images{k});
    if k==1, title(names{k}); else, title(sprintf('%s | %.2f dB',names{k},out.metrics.PSNR(k-1))); end
end
sgtitle(strrep(id,'_',' ')); exportgraphics(f,fullfile(folder,'comparison.png'),'Resolution',150);
end

function make_summary_plot(S,c)
S=S(strcmp(S.Domain,'all'),:);
f=figure('Visible','off','Color','w','Position',[100 100 1000 410]); clean=onCleanup(@()close(f));
tiledlayout(1,2,'Padding','compact');
nexttile; bar(S.MeanPSNR,'FaceColor',[.15 .4 .75]); xticks(1:height(S)); xticklabels(S.Method); xtickangle(20); ylabel('Mean PSNR (dB)'); grid on; title('Held-out grayscale test');
nexttile; bar(S.MeanSSIM,'FaceColor',[.1 .6 .5]); xticks(1:height(S)); xticklabels(S.Method); xtickangle(20); ylabel('Mean SSIM'); ylim([0 1]); grid on; title('12 pixel border excluded');
exportgraphics(f,fullfile(c.root,'results','benchmark.png'),'Resolution',150);
end
