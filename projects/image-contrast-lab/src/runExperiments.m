function runExperiments
root=fileparts(mfilename('fullpath'));out=fullfile(root,'..','实验结果');if ~isfolder(out),mkdir(out);end
cases=jsondecode(fileread(fullfile(root,'..','examples','cases.json')));records=struct([]);n=0;
for i=1:numel(cases)
    c=cases(i);I=readProjectImage(fullfile(root,'..','examples',c.file));
    R=readProjectImage(fullfile(root,'..','examples',c.reference));
    result=enhanceImage(I);exportResults(result,fullfile(out,c.id),c.name);
    if size(R,3)==3,ref=rgb2gray(R);else,ref=R;end
    for k=1:4
        n=n+1;J=result.Images{k};if size(J,3)==3,J=rgb2gray(J);end
        records(n).Case=c.id;records(n).Name=c.name;records(n).Method=result.Names{k};
        records(n).MeanL=result.Metrics(k,1);records(n).StdL=result.Metrics(k,2);
        records(n).Entropy=result.Metrics(k,3);records(n).ClippedPercent=result.Metrics(k,4);
        records(n).ChromaShift=result.Metrics(k,5);records(n).PSNR=psnr(J,ref);records(n).SSIM=ssim(J,ref);
        records(n).Gamma=result.Gamma;records(n).FusionWeight=result.Alpha;
    end
end
T=struct2table(records);writetable(T,fullfile(out,'实验指标.csv'),'Encoding','UTF-8');
fid=fopen(fullfile(out,'实验指标.json'),'w','n','UTF-8');fprintf(fid,'%s',jsonencode(records,'PrettyPrint',true));fclose(fid);
fid=fopen(fullfile(out,'实验条件.txt'),'w','n','UTF-8');
fprintf(fid,'MATLAB %s\n%d个固定案例×4种方法=%d条记录。\n随机种子20261021；ClipLimit=0.01；NumTiles=8×8；融合强度0.75；保边平滑开启。\n12张公开照片经过可复现退化，另1张为程序生成灰度图。各案例构造公式见案例/cases.json。PSNR/SSIM仅针对所提供参考图；不是实际照片的通用准确率。\n',version,numel(cases),n);fclose(fid);
disp(T);
end
