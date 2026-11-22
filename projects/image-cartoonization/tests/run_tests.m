function report = run_tests()
%RUN_TESTS 输入边界、实际 UI 操作、导出和批量容错验证。
root=fileparts(fileparts(mfilename('fullpath')));addpath(root,fullfile(root,'src'));cartoon_check_environment();
out=fullfile(root,'tests','artifacts');if ~isfolder(out),mkdir(out);end
samples=cartoon_samples(root);input=read_image_safe(fullfile(root,'samples',samples(1).file));
input=imresize(input,[120 180]);p=cartoon_defaults();p.MaxDimension=640;
cases=struct('Name',{},'Passed',{},'Details',{});
check('four_presets_valid',@presets);
check('deterministic_and_rng_unchanged',@deterministic);
check('tiny_and_constant_images',@tiny);
check('odd_dimensions_preserved',@odd);
check('grayscale_uint16_float_inputs',@types);
check('invalid_inputs_rejected',@invalid);
check('invalid_parameters_rejected',@parameters);
check('resize_aspect_and_no_upscale',@resize);
check('palette_limit',@palette);
check('sketch_is_grayscale',@sketch);
check('zero_detail_disables_edges',@noEdges);
check('six_file_formats',@formats);
check('alpha_and_indexed_images',@specialFormats);
check('missing_and_corrupt_files',@badFiles);
check('export_readback_and_no_overwrite',@export);
check('batch_continues_after_bad_file',@batchFailure);
check('batch_cancellation_and_empty_input',@batchCancel);
check('gui_workflow_invalid_state_recovery',@gui);
report=struct('MATLAB',version,'Total',numel(cases),'Passed',sum([cases.Passed]), ...
    'Failed',sum(~[cases.Passed]),'Cases',cases);
cartoon_write_json(fullfile(root,'tests','verification.json'),report);
fprintf('TOTAL %d | PASSED %d | FAILED %d\n',report.Total,report.Passed,report.Failed);
assert(report.Failed==0,'Cartoon:Tests','测试失败，详见 tests/verification.json。');
    function check(name,fn)
        try,fn();ok=true;message='PASS';catch err,ok=false;message=err.message;end
        cases(end+1)=struct('Name',name,'Passed',ok,'Details',message);
        fprintf('%s: %s\n',name,message);
    end
    function rejects(fn)
        caught=false;try,fn();catch,caught=true;end
        assert(caught,'Expected operation to reject invalid input.');
    end
    function presets()
        names={'natural','comic','poster','sketch'};results=cell(1,4);
        for i=1:4
            r=cartoon_process(input,cartoon_defaults(names{i}));results{i}=r.Result;
            assert(isa(r.Result,'uint8') && isequal(size(r.Result),size(input)) && all(isfinite(r.Result(:))));
        end
        assert(~isequal(results{1},results{2}) && ~isequal(results{2},results{3}));
    end
    function deterministic()
        before=rng;r1=cartoon_process(input,p);r2=cartoon_process(input,p);
        assert(isequal(r1.Result,r2.Result));assert(isequal(before,rng));
    end
    function tiny()
        for n=[3 4 7]
            r=cartoon_process(uint8(ones(n,n,3)*128),p);assert(~any(r.Edges(:)) && all(isfinite(r.Result(:))));
        end
        r=cartoon_process(zeros(20,30,3,'uint8'),p);assert(~any(r.Result(:)));
    end
    function odd()
        r=cartoon_process(imresize(input,[121 177]),p);assert(isequal(size(r.Result),[121 177 3]));
    end
    function types()
        values={rgb2gray(input),im2uint16(input),im2double(input),im2single(input),rgb2gray(input)>128};
        for i=1:numel(values),r=cartoon_process(values{i},p);assert(size(r.Result,3)==3);end
    end
    function invalid()
        rejects(@()cartoon_process([]));rejects(@()cartoon_process(ones(5,5,4)));
        rejects(@()cartoon_process(nan(5,5)));rejects(@()cartoon_process(ones(5,5)*2));
        rejects(@()cartoon_process(ones(2,2)));rejects(@()cartoon_process(1i*ones(5,5)));
    end
    function parameters()
        q=p;q.Colors=3;rejects(@()cartoon_process(input,q));q=p;q.Colors=12.5;rejects(@()cartoon_process(input,q));
        q=p;q.EdgeDetail=NaN;rejects(@()cartoon_process(input,q));q=p;q.MaxDimension=3000;rejects(@()cartoon_process(input,q));
        q=p;q.Mode='unknown';rejects(@()cartoon_process(input,q));
    end
    function resize()
        q=p;q.MaxDimension=100;r=cartoon_process(input,q);assert(max(size(r.Result,1),size(r.Result,2))==100);
        assert(abs(size(r.Result,2)/size(r.Result,1)-size(input,2)/size(input,1))<.03);
        r=cartoon_process(input,p);assert(r.Scale==1 && isequal(r.InputSize,[120 180]));
    end
    function palette()
        q=p;q.Colors=8;r=cartoon_process(input,q);assert(r.PaletteSize<=8);
        assert(size(unique(reshape(r.Quantized,[],3),'rows'),1)<=8);
    end
    function sketch()
        r=cartoon_process(input,cartoon_defaults('sketch'));
        assert(isequal(r.Result(:,:,1),r.Result(:,:,2)) && isequal(r.Result(:,:,2),r.Result(:,:,3)));
    end
    function noEdges()
        q=p;q.EdgeDetail=0;r=cartoon_process(input,q);assert(~any(r.Edges(:)) && all(r.Outline(:)==255));
    end
    function formats()
        for ext={'.jpg','.jpeg','.png','.bmp','.tif','.tiff'}
            file=fullfile(out,['format' ext{1}]);imwrite(input,file);a=read_image_safe(file);assert(isequal(size(a),size(input)));
        end
    end
    function specialFormats()
        path=fullfile(out,'alpha.png');imwrite(input,path,'Alpha',zeros(size(input,1),size(input,2),'uint8'));
        a=read_image_safe(path);assert(all(a(:)==255));
        [indices,map]=rgb2ind(input,8,'nodither');path=fullfile(out,'indexed.png');imwrite(indices,map,path);
        a=read_image_safe(path);assert(size(a,3)==3);
    end
    function badFiles()
        rejects(@()read_image_safe(fullfile(out,'missing.png')));
        file=fullfile(out,'bad.jpg');fid=fopen(file,'w');fprintf(fid,'not an image');fclose(fid);
        rejects(@()read_image_safe(file));
    end
    function export()
        r=cartoon_process(input,p);a=export_result(r,out,samples(1));b=export_result(r,out,samples(1));
        assert(~strcmp(a,b));assert(isequal(imread(fullfile(a,'05_cartoon.png')),r.Result));
        meta=jsondecode(fileread(fullfile(a,'parameters.json')));assert(meta.Parameters.Colors==p.Colors);
        assert(strcmp(meta.Source.license,samples(1).license) && isfile(fullfile(a,'图片署名与许可.txt')));
    end
    function batchFailure()
        good=fullfile(out,'format.png');bad=fullfile(out,'bad.jpg');
        report=cartoon_batch({bad,good,good},out,p);assert(report.Failed==1 && report.Passed==2 && report.Processed==3);
        assert(~strcmp(report.Items(2).Output,report.Items(3).Output));
    end
    function batchCancel()
        count=0;report=cartoon_batch({fullfile(out,'format.png'),fullfile(out,'format.png')},out,p,@tick,@cancelled);
        assert(report.Cancelled && report.Processed==1);rejects(@()cartoon_batch({},out,p));
        function tick(varargin),count=count+1;end
        function result=cancelled(),result=count>=1;end
    end
    function gui()
        f=run_project('off');clean=onCleanup(@()delete(f)); %#ok<NASGU>
        a=getappdata(f,'CartoonAPI');s=a.getState();assert(~isempty(s.Result));
        original=s.Input;rejects(@()a.load(fullfile(out,'missing.png')));s=a.getState();assert(isequal(original,s.Input));
        a.setValues(struct('Colors',NaN));assert(~a.process());assert(strcmp(get(a.saveButton,'Enable'),'off'));
        rejects(@()a.export(out));a.preset(1);a.setValues(struct('MaxDimension',640));assert(a.process());
        a.preset(4);assert(strcmp(get(a.colors,'Enable'),'off'));assert(a.process());
        set(a.viewMode,'Value',2);set(a.wipe,'Value',0);a.render();s=a.getState();
        assert(isequal(getimage(a.splitAxes),s.Result.Result));
        assert(isempty(get(get(a.originalAxes,'Title'),'String')));
        set(a.wipe,'Value',1);a.render();assert(isequal(getimage(a.splitAxes),s.Result.Original));
        a.compare();s=a.getState();assert(numel(s.StyleResults)==4);assert(~s.Busy);
        a.preset(2);assert(a.process());a.export(out);
        set(f,'Position',[30 30 1200 760]);a.tabs.SelectedTab=a.resultTab;set(a.viewMode,'Value',1);a.render();
        assert(isempty(get(get(a.splitAxes,'Title'),'String')));
        set(f,'PaperPositionMode','auto');print(f,fullfile(out,'主界面.png'),'-dpng','-r100');
        a.tabs.SelectedTab=a.stepsTab;print(f,fullfile(out,'处理步骤.png'),'-dpng','-r100');
    end
end
