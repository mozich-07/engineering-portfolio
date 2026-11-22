function R = apply_model(B,W,model,blend)
if nargin<4, blend=model.blend; end
R=zeros(size(B));
% Chunk by rows to keep 4K-sized inputs from allocating multi-GB patches.
for ch=1:size(B,3)
    for r0=1:128:size(B,1)
        r1=min(r0+127,size(B,1)); lo=max(1,r0-2); hi=min(size(B,1),r1+2);
        X=restorelab.features(B(lo:hi,:,ch),W(lo:hi,:,ch));
        y=((X-model.mu)./model.scale)*model.beta+model.bias;
        y=reshape(y,hi-lo+1,size(B,2));
        y=y(r0-lo+1:r1-lo+1,:);
        % Conservative residual bound is fixed before validation/test.
        y=min(max(y,-0.2),0.2);
        R(r0:r1,:,ch)=W(r0:r1,:,ch)+blend*y;
    end
end
R=restorelab.clip(R);
end
