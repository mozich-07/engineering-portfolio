function [X,Y,bits] = window_features(blocks, K, c)
% WINDOW_FEATURES Real and imaginary neighboring received symbols.
% Evaluation centers fixed for all K, preserving fair sample denominators.
assert(mod(K,2)==1 && K>=1 && (K-1)/2<=c.guard);
n=c.nSymbols*numel(blocks); X=zeros(n,2*K); Y=zeros(n,2);
bits=zeros(n,4,'uint8'); h=(K-1)/2;
centers=(c.guard+1:c.guard+c.nSymbols).';
for b=1:numel(blocks)
    ix=(b-1)*c.nSymbols+(1:c.nSymbols);
    z=blocks(b).rx(centers+(-h:h));
    X(ix,:)=[real(z) imag(z)];
    target=blocks(b).tx(centers);
    Y(ix,:)=[real(target) imag(target)]; bits(ix,:)=blocks(b).bits(centers,:);
end
end
