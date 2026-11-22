function results=run_checks_v2(root)
if nargin<1,root=fileparts(fileparts(mfilename('fullpath')));end
addpath(fullfile(root,'01_程序'));rows={};out=fullfile(root,'07_质量验证');if ~isfolder(out),mkdir(out);end
rng(18);I=rand(48,64,3);copy=I;
check('RGB finite output',@()valid(I));
check('Grayscale 3x3',@()valid(uint8(reshape(1:9,3,3))));
check('Constant identity',@constant);
check('Black identity',@()identity(zeros(20,25,3)));
check('White identity',@()identity(ones(20,25,3)));
check('uint16 input',@()valid(uint16(65535*I)));
check('NaN rejected',@()reject(@()dehaze_v2(NaN(10,10,3))));
check('Out of range rejected',@()reject(@()dehaze_v2(2*ones(10,10,3))));
check('Invalid channels rejected',@()reject(@()dehaze_v2(zeros(10,10,2))));
check('Unknown option rejected',@()reject(@()dehaze_v2(I,struct('bad',1))));
check('Deterministic output',@determinism);
check('Input unchanged',@()assert(isequal(I,copy)));
check('Zero haze identity',@()assert(isequal(synthesize_haze(I,0,5),I)));
check('Synthesis reproducible',@()assert(isequal(synthesize_haze(I,1,5),synthesize_haze(I,1,5))));
check('Synthesis restores RNG',@rngCheck);
check('Metric convention self reference',@metricCheck);
check('Scene groups disjoint',@splitCheck);
check('GUI load process export invalidation',@guiCheck);
results=cell2table(rows,'VariableNames',{'check','passed','detail'});writetable(results,fullfile(out,'checks.csv'));
disp(results);assert(all(results.passed),'Dehaze:Checks','存在未通过的检查');
    function check(name,fn)
        try,fn();rows(end+1,:)={name,true,'OK'};catch err,rows(end+1,:)={name,false,err.message};end
    end
    function valid(X)
        R=dehaze_v2(X);assert(all(isfinite(R.final),'all')&&min(R.final,[],'all')>=0&&max(R.final,[],'all')<=1);
        assert(size(R.final,1)==size(X,1)&&size(R.final,2)==size(X,2)&&size(R.final,3)==3);
    end
    function constant
        X=repmat(reshape([.2 .4 .7],1,1,3),20,25);identity(X);
    end
    function identity(X)
        R=dehaze_v2(X);assert(max(abs(X-R.final),[],'all')<1e-12);
    end
    function reject(fn)
        failed=false;try,fn();catch,failed=true;end;assert(failed,'应当拒绝该输入');
    end
    function determinism
        A=dehaze_v2(I);B=dehaze_v2(I);assert(isequal(A.final,B.final));
    end
    function rngCheck
        before=rng;synthesize_haze(I,1,5);after=rng;assert(isequal(before,after));
    end
    function metricCheck
        q=paired_quality(I,I);assert(isinf(q.psnr)&&abs(q.ssim-1)<1e-12&&q.mae==0);
    end
    function splitCheck
        T=readtable(fullfile(root,'02_数据集','manifest.csv'),'TextType','string');
        assert(height(T)==110&&numel(unique(T.scene_id))==55);
        assert(isempty(intersect(T.group_id(T.split=="development"),T.group_id(T.split=="test"))));
        for k=1:height(T),assert(isfile(fullfile(root,'02_数据集',T.path(k))));end
    end
    function guiCheck
        f=dehaze_studio('off');clean=onCleanup(@()delete(f)); %#ok<NASGU>
        api=getappdata(f,'DehazeV2API');api.loadSample(1);s=api.state();assert(s.hasInput&&s.hasReference&&~s.hasResult);
        api.process();s=api.state();assert(s.hasResult);
        folder=api.export(out);assert(isfile(fullfile(folder,'final.png'))&&isfile(fullfile(folder,'parameters.json')));
        api.strength.Value=.4;feval(api.strength.ValueChangedFcn,api.strength,[]);s=api.state();assert(~s.hasResult);
        api.simulate();s=api.state();assert(~s.hasResult&&s.hasReference);
        api.process();drawnow;exportapp(f,fullfile(out,'工作台.png'));
        reject(@()api.load(fullfile(root,'missing.png')));s=api.state();assert(~s.hasResult&&~s.hasInput);
    end
end
