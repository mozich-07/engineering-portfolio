function comparison(out,reference,path,label)
% Export a readable six-panel comparison for demonstrations.
f=figure('Visible','off','Color','w','Position',[100 100 1200 700]);
clean=onCleanup(@()close(f));
tiledlayout(2,3,'Padding','compact','TileSpacing','compact');
names={'Reference','Blurred input','Sharpen only','Wiener','Learned residual','Final'};
images={reference,out.input,out.sharpenOnly,out.wiener,out.learned,out.final};
for k=1:6
    nexttile;
    if isempty(images{k}), axis off; text(.5,.5,'No reference','HorizontalAlignment','center');
    else, imshow(images{k}); end
    if k>1 && out.hasReference
        title(sprintf('%s | %.2f dB',names{k},out.metrics.PSNR(k-1)));
    else, title(names{k}); end
end
sgtitle(strrep(label,'_',' '),'Interpreter','none');
exportgraphics(f,path,'Resolution',120);
end
