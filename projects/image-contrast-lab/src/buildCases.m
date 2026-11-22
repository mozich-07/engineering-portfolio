function buildCases
root=fileparts(mfilename('fullpath'));folder=fullfile(root,'..','examples');if ~isfolder(folder),mkdir(folder);end
rng(20261021,'twister');
ids={'lowlight','lowcontrast','color','overexposed','noise','mountain','lake','forest','ocean','leaves','books','bedroom','food'};
names={'暗光背包','低对比度相机','彩色运动鞋','过亮手表','含噪灰度测试图','低对比度山谷','非均匀照明湖泊','暗光森林','过亮海浪','含噪绿叶','低对比度台灯','偏亮卧室','低对比度餐食'};
notes={'观察暗部提亮和噪声变化','观察直方图展开及HE的强增强','观察只处理亮度后的色彩变化','已截断的亮部细节无法恢复','观察CLAHE放大噪声与融合处理的取舍','灰度山谷适合解释CDF展开与层次','左右亮度不同，观察局部统计的作用','观察林间暗部与原有光照氛围','观察高亮波纹和端点像素','细密叶片纹理与噪声同时存在','观察大面积平滑墙面与台灯边缘','观察亮色室内物体的纹理与饱和','观察多种食材的色调与亮度分布'};
sources={'bag.jpg','camera.jpg','shoe.jpg','watch.jpg','程序生成','mountain.jpg','lake.jpg','forest.jpg','ocean.jpg','leaves.jpg','books.jpg','bedroom.jpg','food.jpg'};
recipes={'I=0.5R^1.8','gray: I=0.30+0.32R','Lab: Lnew=30+0.35L','I=min(1,0.32+0.85R)','I=clip(0.25+0.3R+0.02N)','gray: I=0.22+0.42R','I=R*(0.30+0.60x), x in [0,1]','I=0.60R^1.6','I=min(1,0.26+0.90R)','I=clip(0.20+0.45R+0.018N)','I=0.28+0.36R','I=min(1,0.22+0.90R)','Lab: Lnew=25+0.45L'};
records=struct([]);
for k=1:numel(ids)
    if k~=5
        R=im2double(imread(fullfile(root,'..','examples','sources',sources{k})));
        R=imresize(R,min(1,800/max(size(R,1),size(R,2))));
    else
        [x,y]=meshgrid(linspace(0,1,800),linspace(0,1,520));
        R=.15+.6*x+.10*sin(14*pi*x).*cos(10*pi*y);
        R((x-.25).^2+(y-.5).^2<.10^2)=.85;
        R(x>.65 & x<.85 & y>.3 & y<.7)=.25;
        R=min(max(R,0),1);
    end
    switch k
        case 1,I=.5*R.^1.8;
        case 2,R=rgb2gray(R);I=.30+.32*R;
        case 3,lab=rgb2lab(R);lab(:,:,1)=30+.35*lab(:,:,1);I=min(max(lab2rgb(lab),0),1);
        case 4,I=min(1,.32+.85*R);
        case 5,I=min(max(.25+.3*R+.02*randn(size(R)),0),1);
        case 6,R=rgb2gray(R);I=.22+.42*R;
        case 7,x=linspace(0,1,size(R,2));I=R.*reshape(.30+.60*x,1,[],1);
        case 8,I=.60*R.^1.6;
        case 9,I=min(1,.26+.90*R);
        case 10,I=min(max(.20+.45*R+.018*randn(size(R)),0),1);
        case 11,I=.28+.36*R;
        case 12,I=min(1,.22+.90*R);
        case 13,lab=rgb2lab(R);lab(:,:,1)=25+.45*lab(:,:,1);I=min(max(lab2rgb(lab),0),1);
    end
    imwrite(R,fullfile(folder,[ids{k} '_reference.png']));
    imwrite(I,fullfile(folder,[ids{k} '.png']));
    records(k).id=ids{k};records(k).name=names{k};records(k).file=[ids{k} '.png'];
    records(k).reference=[ids{k} '_reference.png'];records(k).note=notes{k};records(k).source=sources{k};
    records(k).recipe=recipes{k};
end
fid=fopen(fullfile(folder,'cases.json'),'w','n','UTF-8');c=onCleanup(@()fclose(fid));
fprintf(fid,'%s',jsonencode(records,'PrettyPrint',true));
end
