function [hazy,transmission,depth,A] = synthesize_haze(clearImage,beta,seed,mode)
% Controlled image degradation. depth is a simulated field, never true scene depth.
if nargin<4,mode='nonuniform';end
validateattributes(beta,{'numeric'},{'scalar','finite','real','>=',0,'<=',3});
validateattributes(seed,{'numeric'},{'scalar','integer','nonnegative'});
if ~ismember(mode,{'nonuniform','smooth'}),error('Dehaze:Mode','模式无效');end
J=im2double(clearImage);if ismatrix(J),J=repmat(J,1,1,3);end
validateattributes(J,{'double'},{'real','finite','>=',0,'<=',1});
old=rng;rngCleanup=onCleanup(@()rng(old)); %#ok<NASGU>
rng(seed,'twister');[h,w,~]=size(J);
[y,x]=ndgrid(linspace(0,1,h),linspace(0,1,w));
depth=.2+.8*(1-y).^0.8;
if strcmp(mode,'nonuniform')
    field=imresize(imgaussfilt(rand(24,32),2),[h w]);
    depth=.15+.55*depth+.65*mat2gray(field)+.15*sin(2*pi*x).^2;
end
A=reshape([.88 .92 .98],1,1,3);
transmission=exp(-beta*depth);
hazy=J.*transmission+A.*(1-transmission);
end
