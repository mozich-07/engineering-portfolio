function tests=test_restoration
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.c=setup_project(); t.TestData.model=restorelab.load_model(t.TestData.c);
t.TestData.I=im2double(imread(fullfile(t.TestData.c.root,'data','clean','synthetic_test_001.png')));
end
function testPSF(t)
for p=t.TestData.c.cases
    K=restorelab.make_psf(p); verifyEqual(t,sum(K(:)),1,'AbsTol',1e-12); verifyGreaterThanOrEqual(t,min(K(:)),0);
end
verifyError(t,@()restorelab.make_psf(struct('kind','invalid','strength',2,'angle',0)),'RestoreLab:Kind');
end
function testReproducibleNoiseWithoutGlobalRNG(t)
before=rng; B=restorelab.degrade(t.TestData.I,t.TestData.c.cases(1),.01,123);
verifyEqual(t,rng,before); verifyEqual(t,B,restorelab.degrade(t.TestData.I,t.TestData.c.cases(1),.01,123));
verifyNotEqual(t,B,restorelab.degrade(t.TestData.I,t.TestData.c.cases(1),.01,124));
end
function testSourceIsolation(t)
M=readtable(t.TestData.c.manifestPath,'TextType','string');
verifyEqual(t,numel(unique(M.SourceID)),height(M)); verifyEqual(t,numel(unique(M.RelativePath)),height(M));
testIDs=M.SourceID(M.Split=="test"); fitIDs=string([t.TestData.model.trainSources;t.TestData.model.validationSources]);
verifyEmpty(t,intersect(testIDs,fitIDs)); verifyGreaterThan(t,t.TestData.model.trainSamples,100000);
verifyGreaterThan(t,norm(t.TestData.model.beta),1e-6);
end
function testNoReferenceScores(t)
m=restorelab.metrics(t.TestData.I,[],12); verifyTrue(t,isnan(m.PSNR)); verifyTrue(t,isnan(m.SSIM));
verifyTrue(t,isfinite(m.GradientEnergy));
end
function testMetricIdentity(t)
m=restorelab.metrics(t.TestData.I,t.TestData.I,12); verifyEqual(t,m.PSNR,Inf); verifyEqual(t,m.RMSE,0); verifyEqual(t,m.SSIM,1,'AbsTol',1e-10);
end
function testReferenceCannotAffectRestoration(t)
I=t.TestData.I; p=t.TestData.c.cases(2); B=restorelab.degrade(I,p,.015,41);
A=restorelab.process(B,p,.015,t.TestData.model,0,I);
C=restorelab.process(B,p,.015,t.TestData.model,0,[]);
verifyEqual(t,A.final,C.final); verifyTrue(t,all(isnan(C.metrics.PSNR)));
end
function testChunkingMatchesFullPrediction(t)
B=restorelab.degrade(t.TestData.I,t.TestData.c.cases(4),.015,87);
W=restorelab.wiener_restore(B,t.TestData.c.cases(4),.015); m=t.TestData.model;
F=restorelab.features(B,W); y=((F-m.mu)./m.scale)*m.beta+m.bias;
y=reshape(min(max(y,-.2),.2),size(B)); expected=restorelab.clip(W+m.blend*y);
verifyEqual(t,restorelab.apply_model(B,W,m),expected,'AbsTol',1e-12);
end
function testRGBAndBounds(t)
I=repmat(t.TestData.I,[1 1 3]); I(:,:,2)=.7*I(:,:,2);
B=restorelab.degrade(I,t.TestData.c.cases(3),.015,56);
out=restorelab.process(B,t.TestData.c.cases(3),.015,t.TestData.model,.3,I);
verifySize(t,out.final,size(I)); verifyTrue(t,all(isfinite(out.final(:))));
verifyGreaterThanOrEqual(t,min(out.final(:)),0); verifyLessThanOrEqual(t,max(out.final(:)),1);
end
function testZeroSharpenIdentity(t)
verifyEqual(t,restorelab.sharpen(t.TestData.I,0),t.TestData.I);
end
function testExport(t)
folder=tempname; mkdir(folder); clean=onCleanup(@()rmdir(folder,'s'));
out=restorelab.process(t.TestData.I,t.TestData.c.cases(1),.005,t.TestData.model,0,[]);
restorelab.export_result(out,folder); verifyTrue(t,isfile(fullfile(folder,'final.png')));
meta=jsondecode(fileread(fullfile(folder,'parameters.json'))); verifyFalse(t,meta.hasReference);
R=readtable(fullfile(folder,'metrics.csv')); verifyTrue(t,all(isnan(R.PSNR)));
end
function testUIStateTransitions(t)
app=start_project('off'); clean=onCleanup(@()delete(app));
app.ingestImage(t.TestData.I); verifyEmpty(t,app.Input); app.simulate(); app.restore();
verifyEqual(t,app.Axes(1).XLim,[.5 size(t.TestData.I,2)+.5]);
verifyEqual(t,app.Axes(1).YLim,[.5 size(t.TestData.I,1)+.5]);
verifyNotEmpty(t,app.Output); app.Strength.Value=2; app.parametersChanged();
verifyEmpty(t,app.Input); verifyEmpty(t,app.Output); verifyEqual(t,char(app.ExportButton.Enable),'off');
app.Mode.Value='real'; app.changeMode(); verifyEmpty(t,app.Reference); verifyNotEmpty(t,app.Input);
app.restore(); verifyTrue(t,all(isnan(app.Output.metrics.PSNR)));
end
function testBatchIsolationAndNoOverwrite(t)
folder=tempname; mkdir(folder); clean=onCleanup(@()rmdir(folder,'s'));
in=fullfile(folder,'in'); out=fullfile(folder,'out'); mkdir(in);
imwrite(t.TestData.I,fullfile(in,'ok.png'));
fid=fopen(fullfile(in,'broken.png'),'w'); fwrite(fid,'not an image'); fclose(fid);
R=batch_restore(in,out,'gaussian',1.5,0,.015,0);
verifyEqual(t,sum(strcmp(R.Status,'ok')),1); verifyEqual(t,sum(strcmp(R.Status,'error')),1);
verifyTrue(t,isfile(fullfile(out,'ok_png','final.png')));
R2=batch_restore(in,out,'gaussian',1.5,0,.015,0);
verifyEqual(t,sum(strcmp(R2.Status,'ok')),0);
end
function testConstantImageFinite(t)
I=ones(64)*.5; B=restorelab.degrade(I,t.TestData.c.cases(1),.005,88);
out=restorelab.process(B,t.TestData.c.cases(1),.005,t.TestData.model,0,I);
verifyTrue(t,all(isfinite(out.final(:))));
end
function testGallerySelection(t)
app=start_project('off'); clean=onCleanup(@()delete(app));
verifyEqual(t,numel(app.Gallery),15);
app.Example.Value='balloon'; app.loadExample(); verifyNotEmpty(t,app.Reference);
verifyLessThanOrEqual(t,max(size(app.Reference,[1 2])),640);
app.Mode.Value='real'; app.changeMode(); app.loadExample();
verifyEmpty(t,app.Reference); verifyNotEmpty(t,app.Input);
verifyEqual(t,app.Strength.Value,1.5); verifyEqual(t,app.Noise.Value,.015);
end
function testResizedImageRange(t)
folder=tempname; mkdir(folder); clean=onCleanup(@()rmdir(folder,'s'));
I=zeros(256,256,3); I(:,129:end,:)=1;
path=fullfile(folder,'edge.png'); imwrite(I,path);
R=restorelab.read_image(path,129);
verifyGreaterThanOrEqual(t,min(R(:)),0);
verifyLessThanOrEqual(t,max(R(:)),1);
end
