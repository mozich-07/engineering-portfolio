function test_project(outputRoot)
% TEST_PROJECT Mathematical invariants and delivery consistency.
codeDir=fileparts(mfilename('fullpath')); addpath(codeDir);
if nargin<1, outputRoot=fileparts(codeDir); end
c=fiber_config(); rng(99); bits=uint8(randi([0 1],8192,4)); x=qam16(bits,'mod');
assert(isequal(qam16(x,'demod'),bits),'Gray mapper round trip');
assert(max(abs(cd_filter(x,0,c)-x))<1e-11,'Zero-length identity');
y=cd_filter(x,80,c); z=cd_filter(y,-80,c);
assert(max(abs(z-x))<1e-11,'Dispersion inverse');
assert(abs(sum(abs(x).^2)-sum(abs(y).^2))/sum(abs(x).^2)<1e-12,'Power preservation');
a=make_blocks(c,1,18,80,1234,'test'); b=make_blocks(c,1,18,80,1234,'test');
assert(isequal(a.rx,b.rx),'Seed reproducibility');
[X,Y]=window_features(a,31,c); assert(isequal(size(X),[c.nSymbols 62]));
assert(isequal(X(:,16),real(a.rx(c.guard+(1:c.nSymbols)))),'Window center alignment');
m=fit_ridge(X,Y,.001); old=predict_ridge(m,X); a.bits(:)=1-a.bits(:);
[X2,~]=window_features(a,31,c); assert(isequal(old,predict_ridge(m,X2)),'Inference must not use labels');
manifest=readtable(fullfile(outputRoot,'data','block_manifest.csv'));
assert(numel(unique(manifest.Seed))==height(manifest),'Disjoint block seeds');
assert(height(manifest)==c.trainBlocks+c.valBlocks+c.testBlocks*(numel(c.testSnrs)+2));
q=load(fullfile(outputRoot,'results','results.mat')); r=q.results;
assert(all(r.summary.TotalBits==c.testBlocks*c.nSymbols*4),'Correct denominators');
assert(all(r.summary.BER==r.summary.BitErrors./r.summary.TotalBits),'Counts reproduce BER');
[minVal,index]=min(r.search.ValidationNMSE);
assert(r.model.K==r.search.Window(index) && r.model.lambda==r.search.Lambda(index));
assert(abs(r.model.validationNMSE-minVal)<1e-14,'Validation-only selection');
t=r.summary(r.summary.SNRdB==18,:);
assert(t.BER(strcmp(t.Method,'RidgeML'))<t.BER(strcmp(t.Method,'Uncompensated')),'Expected improvement');
fprintf('PASS: 15 mathematical, split, inference, and result consistency checks.\n');
end
