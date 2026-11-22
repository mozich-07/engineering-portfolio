function r = region_dehaze(image, options)
%REGION_DEHAZE Region-adaptive physical restoration, V2.
% Does not accept a ground-truth image, depth or transmission as input.
% All heuristic confidence maps are relative scores, not physical visibility.
if nargin<2, options=struct; end
c=struct('strength',0.90,'skyProtection',0.55,'detailScale',0.50, ...
    'minTransmission',0.16,'guard',true,'refine',true,'airlightMode','robust');
if ~isstruct(options)||~isscalar(options),error('Dehaze:Options','选项必须是标量结构体。');end
keys=fieldnames(options);
for k=1:numel(keys)
    if ~isfield(c,keys{k}),error('Dehaze:Options','未知选项 %s',keys{k});end
    c.(keys{k})=options.(keys{k});
end
for key={'strength','skyProtection','detailScale'}
    validateattributes(c.(key{1}),{'numeric'},{'real','finite','scalar','>=',0,'<=',1.2});
end
validateattributes(c.minTransmission,{'numeric'},{'real','finite','scalar','>=',.05,'<=',1});
validateattributes(c.guard,{'logical'},{'scalar'});validateattributes(c.refine,{'logical'},{'scalar'});
if ~ismember(c.airlightMode,{'robust','maximum'}),error('Dehaze:Options','无效大气光模式');end
validateattributes(image,{'uint8','uint16','single','double','logical'},{'nonempty','real','finite','nonsparse'});
if ndims(image)>3 || (~ismatrix(image)&&size(image,3)~=3)||min(size(image,1),size(image,2))<3
    error('Dehaze:Input','请输入至少 3×3 的灰度或 RGB 图。');
end
if isfloat(image)&&(min(image(:))<0||max(image(:))>1),error('Dehaze:Range','浮点输入范围必须为 [0,1]。');end
I=im2double(image);if ismatrix(I),I=repmat(I,1,1,3);end
G=rgb2gray(I);[h,w,~]=size(I);
patch=max(3,min(15,2*floor(min(h,w)/80)+1));
dark=imerode(min(I,[],3),strel('square',patch));
gradient=imgradient(G); smooth=exp(-gradient/max(prctile(gradient(:),80),.025));
HSV=rgb2hsv(I);V=HSV(:,:,3);S=HSV(:,:,2);
[Y,~]=ndgrid(linspace(0,1,h),1:w);
skyCandidate=V>.55 & S<.32 & smooth>.40 & Y<.65;
% Top-connected component constraint reduces confusion with isolated white objects.
marker=false(h,w);marker(1:max(1,round(.04*h)),:)=skyCandidate(1:max(1,round(.04*h)),:);
skyRegion=imreconstruct(marker,skyCandidate);
sky=imgaussfilt(double(skyRegion),max(1,min(h,w)/180),'Padding','replicate');
sky=sky.*min(1,max(0,(V-.42)/.35)).*smooth;
[~,idx]=sort(dark(:),'descend');n=max(1,round(.001*numel(G)));
pixels=reshape(I,[],3);cand=pixels(idx(1:n),:);
if strcmp(c.airlightMode,'maximum')
    [~,j]=max(sum(cand,2));A=cand(j,:);
else
    % Channel-wise median resists a single specular/noisy brightest candidate.
    A=median(cand,1);
end
A=min(.99,max(.35,A));
N=I./reshape(A,1,1,3);
dSmall=imerode(min(N,[],3),strel('square',max(3,2*floor(patch/4)+1)));
dLarge=imerode(min(N,[],3),strel('square',patch));
edge=min(1,gradient/max(prctile(gradient(:),90),.03));
darkNorm=(1-c.detailScale.*edge).*dLarge+c.detailScale.*edge.*dSmall;
% Less inversion in top-connected bright smooth regions.
omega=c.strength.*(1-c.skyProtection.*sky);
tRaw=1-omega.*min(darkNorm,1);
if c.refine
    side=max(3,2*floor(min(20,min(h,w)/12))+1);
    t=imguidedfilter(tRaw,G,'NeighborhoodSize',[side side],'DegreeOfSmoothing',.001);
else,t=tRaw;end
t=max(c.minTransmission,min(1,t));
J=(I-reshape(A,1,1,3))./t+reshape(A,1,1,3);
clipMask=any(J<0|J>1,3);
J=max(0,min(1,J));
spread=diff(prctile(G(:),[5 95]));
score=max(0,min(1,.65*mean(dark(:))/.5+.35*(.6-spread)/.6));
% Reversible low-haze gate avoids a mandatory contrast/white-balance change.
gate=min(1,max(0,(prctile(dark(:),60)-.025)/.13));
gate=gate*(.65+.35*min(1,score/.45));
if ~c.guard,gate=1;end
alpha=gate*ones(h,w);
if c.guard
    % Inversion magnifies noise when t is small. A floor-limited smooth blend
    % reduces impact in very smooth regions; it is not a learned denoiser.
    risk=imgaussfilt(double(clipMask),max(1,min(h,w)/250));
    alpha=alpha.*(1-.35*risk);
end
final=I.*(1-alpha)+J.*alpha;
flat=max(reshape(max(I,[],[1 2])-min(I,[],[1 2]),[],1))<1e-12;
if flat,final=I;alpha(:)=0;gate=0;end
warning='经验判断并非真实雾浓度或距离，浓雾与白色物体可能误判。';
if gate<.25,warning='低雾证据或无纹理，采用保守处理；可手动提高强度。';end
r=struct('input',I,'final',final,'physical',J,'darkChannel',dark, ...
    'transmissionRaw',tRaw,'transmission',t,'skyConfidence',sky, ...
    'strengthMap',omega,'blendMap',alpha,'clipRisk',double(clipMask), ...
    'atmosphericLight',A,'hazeScore',score,'gate',gate,'options',c,'warning',warning);
end
