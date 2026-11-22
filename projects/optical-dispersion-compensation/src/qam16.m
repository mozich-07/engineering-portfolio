function out = qam16(in, mode)
% QAM16 Unit expected energy Gray 16-QAM, no Communications Toolbox.
levels=[-3 -1 3 1]; % bit pairs 00,01,10,11
if strcmp(mode,'mod')
    b=double(in); assert(size(b,2)==4,'Bits must be N x 4.');
    out=(levels(2*b(:,1)+b(:,2)+1).'+1i*levels(2*b(:,3)+b(:,4)+1).')/sqrt(10);
else
    z=in(:)*sqrt(10);
    [~,a]=min(abs(real(z)-levels),[],2);
    [~,b]=min(abs(imag(z)-levels),[],2);
    a=a-1; b=b-1;
    out=uint8([floor(a/2),mod(a,2),floor(b/2),mod(b,2)]);
end
end
