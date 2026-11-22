function m = signal_metrics(z, target, bits)
% SIGNAL_METRICS BER, SER, EVM and descriptive Wilson bit interval.
pred=qam16(z,'demod'); e=pred~=bits;
m.errors=sum(e(:)); m.nBits=numel(bits); m.BER=m.errors/m.nBits;
m.SER=mean(any(e,2)); m.NMSE=mean(abs(z-target).^2)/mean(abs(target).^2);
m.EVM=100*sqrt(m.NMSE); n=m.nBits; p=m.BER; a=1.96;
center=(p+a^2/(2*n))/(1+a^2/n);
half=a*sqrt(p*(1-p)/n+a^2/(4*n^2))/(1+a^2/n);
m.ciLow=max(0,center-half); m.ciHigh=min(1,center+half);
% These binomial intervals are descriptive; residual errors may correlate.
end
