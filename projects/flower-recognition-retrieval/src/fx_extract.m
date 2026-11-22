function [H,D]=fx_extract(T,net,force)
if nargin<3,force=false;end
c=fx_config();cache=fullfile(c.models,'features.mat');
if isfile(cache)&&~force,s=load(cache);assert(isequal(T.SHA256,s.hashes));H=s.H;D=s.D;return;end
H=zeros(height(T),1264,'single');
for i=1:height(T)
 H(i,:)=fx_features(fullfile(c.root,T.Path(i)));
 if mod(i,500)==0,fprintf('Handcrafted features %d/%d\n',i,height(T));end
end
fprintf('Extracting 512-D pretrained features on %s...\n',c.environment);
D=activations(net,fx_datastore(T,false),'pool5','OutputAs','rows','MiniBatchSize',64,'ExecutionEnvironment',c.environment);
D=single(D);hashes=T.SHA256;save(cache,'H','D','hashes','-v7.3');
end
