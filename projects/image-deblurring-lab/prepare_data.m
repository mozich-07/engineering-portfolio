function manifest = prepare_data()
% PREPARE_DATA Build source-group split BEFORE any patches/degradation.
c=setup_project(); rows={}; splitNames={'train','val','test'};
for s=1:3
    for k=1:c.counts(s)
        id=sprintf('synthetic_%s_%03d',splitNames{s},k);
        I=make_scene(c.imageSize,c.seed+s*10000+k);
        rel=fullfile('data','clean',[id '.png']); imwrite(I,fullfile(c.root,rel));
        rows(end+1,:)={id,splitNames{s},'procedural',rel,c.seed+s*10000+k}; %#ok<AGROW>
    end
end
names={'coffee.png','brick.png','grass.png','gravel.png','chelsea.png','astronaut.png','rocket.jpg'};
splits={'train','train','train','val','test','test','test'};
for k=1:numel(names)
    file=fullfile(c.root,'data','external',names{k});
    assert(isfile(file),'RestoreLab:Data','缺少随项目提供的样例图像：%s',names{k});
    I=restorelab.read_image(file);
    I=imresize(I,c.imageSize/min(size(I,1),size(I,2)));
    a=floor((size(I,1)-c.imageSize)/2)+1; b=floor((size(I,2)-c.imageSize)/2)+1;
    I=I(a:a+c.imageSize-1,b:b+c.imageSize-1,:);
    [~,id]=fileparts(names{k}); id=['natural_' id];
    rel=fullfile('data','clean',[id '.png']); imwrite(I,fullfile(c.root,rel));
    rows(end+1,:)={id,splits{k},'natural',rel,0}; %#ok<AGROW>
end
manifest=cell2table(rows,'VariableNames',{'SourceID','Split','Domain','RelativePath','Seed'});
writetable(manifest,c.manifestPath,'Encoding','UTF-8');
fprintf('Prepared %d source images; train=%d, val=%d, test=%d.\n',height(manifest), ...
    sum(strcmp(manifest.Split,'train')),sum(strcmp(manifest.Split,'val')),sum(strcmp(manifest.Split,'test')));
end

function I=make_scene(n,seed)
s=RandStream('mt19937ar','Seed',seed); [x,y]=meshgrid(linspace(-1,1,n));
I=0.3+0.18*x+0.14*y;
% Random multiscale smooth texture, edges, ellipses, bars and fine patterns.
for j=1:4
    field=imgaussfilt(randn(s,n,n),0.6*2^j,'Padding','symmetric');
    I=I+0.05*field/max(std(field(:)),eps);
end
for j=1:22
    cx=1.8*rand(s)-0.9; cy=1.8*rand(s)-0.9;
    w=0.04+0.45*rand(s); h=0.04+0.4*rand(s);
    if mod(j,3)==0
        mask=abs(x-cx)<w & abs(y-cy)<h;
    else
        mask=((x-cx)/w).^2+((y-cy)/h).^2<1;
    end
    I(mask)=0.08+0.84*rand(s);
end
a=pi*rand(s); freq=4+20*rand(s);
I=I+0.035*sin(freq*pi*(cos(a)*x+sin(a)*y));
for j=1:6
    a=pi*rand(s); offset=1.5*rand(s)-0.75;
    mask=abs(cos(a)*x+sin(a)*y-offset)<0.007+0.012*rand(s);
    I(mask)=0.1+0.8*rand(s);
end
I=restorelab.clip(I);
end
