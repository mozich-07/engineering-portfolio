function r = dehaze_v2(image,options)
%DEHAZE_V2 Main restoration plus controlled region-adaptive residual correction.
% Default constants selected on NH-HAZE development IDs 01-15 only.
% Original V1 is retained unmodified in adaptive_dehaze_image.m.
if nargin<2,options=struct;end
defaults=struct('strength',.65,'skyProtection',.55,'detailScale',.50, ...
 'minTransmission',.16,'guard',true,'refine',true,'airlightMode','robust','residual',true);
keys=fieldnames(options);
for k=1:numel(keys)
 if ~isfield(defaults,keys{k}),error('Dehaze:Options','未知选项 %s',keys{k});end
 defaults.(keys{k})=options.(keys{k});
end
options=defaults;validateattributes(options.residual,{'logical'},{'scalar'});
base=adaptive_dehaze_image(image);
physicalOptions=rmfield(options,'residual');
if ~options.residual,physicalOptions.strength=0;end
r=region_dehaze(base.final,physicalOptions);
I=base.input;
gate=min(1,max(0,(prctile(base.darkChannel(:),60)-.025)/.13));
if ~options.guard,gate=1;end
if max(max(max(I,[],[1 2])-min(I,[],[1 2])))<1e-12,gate=0;end
r.final=I+gate*(r.final-I);
r.input=I;r.baseline=base.final;r.retinex=base.retinex;r.dcp=base.dcp;
r.mainTransmission=base.transmission;r.mainAtmosphere=base.atmosphericLight;
r.darkChannel=base.darkChannel;r.inputGate=gate;r.options=options;
r.status='处理完成';
if gate<.25,r.status='弱雾证据，降低整体处理幅度';end
% Diagnostics are heuristics. No ground truth is used here.
r.warning=[r.warning ' 两阶段透射率用于解释各阶段，不等于场景真实深度。'];
end
