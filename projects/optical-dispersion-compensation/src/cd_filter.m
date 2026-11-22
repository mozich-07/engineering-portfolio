function y = cd_filter(x, lengthKm, c)
% CD_FILTER Unitary discrete chromatic-dispersion transfer function.
% Envelope equation dA/dz=-j*beta2/2*d2A/dt2, H=exp(+j*beta2*L*w^2/2).
% Inverse propagation uses negative L.
% Ideal Nyquist, one complex sample/symbol; not a full optical frontend.
x=x(:); n=numel(x);
f=ifftshift((-floor(n/2):ceil(n/2)-1).')*(c.symbolRate/n);
H=exp(1i*0.5*c.beta2*(lengthKm*1000)*(2*pi*f).^2);
y=ifft(fft(x).*H);
end
