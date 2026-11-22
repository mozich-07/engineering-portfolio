function run_original_v2(root)
if nargin<1,root=fileparts(fileparts(mfilename('fullpath')));end
folder=fullfile(root,'02_数据集','原有真实雾图');files=dir(fullfile(folder,'*.jpg'));
out=fullfile(root,'03_实验结果','original_unpaired');if ~isfolder(out),mkdir(out);end
rows={};
for k=1:numel(files)
 I=dehaze_read_image(fullfile(folder,files(k).name));timer=tic;R=dehaze_v2(I);elapsed=toc(timer);
 [~,name]=fileparts(files(k).name);dest=fullfile(out,name);if ~isfolder(dest),mkdir(dest);end
 imwrite(I,fullfile(dest,'input.png'));imwrite(R.baseline,fullfile(dest,'V1.png'));imwrite(R.final,fullfile(dest,'V2.png'));
 rows(end+1,:)={files(k).name,size(I,2),size(I,1),elapsed,R.inputGate}; %#ok<AGROW>
end
writetable(cell2table(rows,'VariableNames',{'file','width','height','seconds','input_gate'}),fullfile(out,'processing.csv'));
end
