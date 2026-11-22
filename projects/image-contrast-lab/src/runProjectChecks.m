function runProjectChecks(out)
if nargin<1,out=fullfile(fileparts(mfilename('fullpath')),'..','实验结果','验收');end
if ~isfolder(out),mkdir(out);end
checks={};
A=uint8(repmat(linspace(30,160,256),128,1));r=enhanceImage(A);
assert(numel(r.Images)==4);assert(isequal(size(r.Images{4}),size(A)));checks{end+1}='灰度四方法及尺寸';
v=r.Images{2}(1,:);assert(all(diff(double(v))>=0));checks{end+1}='HE映射单调';
for value=[0 127 255]
    A=uint8(ones(64)*value);r=enhanceImage(A);assert(isequal(r.Images{1},r.Images{4}));
end
checks{end+1}='全黑常量全白保护';
failed=false;try,enhanceImage(zeros(8));catch,failed=true;end;assert(failed);checks{end+1}='过小图片拒绝';
failed=false;try,enhanceImage(nan(32));catch,failed=true;end;assert(failed);checks{end+1}='非有限输入拒绝';
root=fileparts(mfilename('fullpath'));I=readProjectImage(fullfile(root,'..','examples','color.png'));
imwrite(I,fullfile(out,'中文测试 图片.png'));J=readProjectImage(fullfile(out,'中文测试 图片.png'));assert(isequal(I,J));checks{end+1}='中文含空格路径';
r=enhanceImage(I);assert(all(isfinite(r.Metrics(:))));checks{end+1}='彩色图与有限指标';
exportResults(r,fullfile(out,'导出验证'),'中文测试');files=dir(fullfile(out,'导出验证','*.png'));assert(numel(files)==5);checks{end+1}='图片指标参数导出';
fig=HistogramStudio;cleanup=onCleanup(@()delete(fig));u=fig.UserData;u.RunCompare();
assert(~isempty(u.GetResult()));assert(strcmp(u.Save.Enable,'on'));checks{end+1}='实际界面计算回调';
drawnow;exportapp(fig,fullfile(out,'MATLAB界面.png'));
u.Case.Value=2;u.LoadCase();assert(isempty(u.GetResult()));assert(strcmp(u.Save.Enable,'off'));checks{end+1}='换案例清除旧结果';
u.RunCompare();u.Clip.Value=.02;u.Invalidate();assert(isempty(u.GetResult()));checks{end+1}='修改参数清除旧结果';
u.RunCompare();u.Export(fullfile(out,'界面导出'));assert(isfile(fullfile(out,'界面导出','自适应融合.png')));checks{end+1}='界面结果导出';
assert(numel(u.Case.Items)==13);
for i=1:numel(u.Case.Items)
    u.Case.Value=i;u.LoadCase();assert(isempty(u.GetResult()));u.RunCompare();
    current=u.GetResult();assert(numel(current.Images)==4);assert(all(isfinite(current.Metrics(:))));
end
checks{end+1}='全部13个内置案例真实界面切换与计算';
drawnow;pause(1); % 等待图像界面异步绘制完成后再退出检查。
fid=fopen(fullfile(out,'检查结果.json'),'w','n','UTF-8');fprintf(fid,'%s',jsonencode(struct('Passed',numel(checks),'Checks',{checks}),'PrettyPrint',true));fclose(fid);
fprintf('CHECKS_PASSED=%d\n',numel(checks));
end
