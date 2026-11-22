function blocks = make_blocks(c, nBlocks, snrDb, lengthKm, seedBase, split)
% MAKE_BLOCKS Each independent block is assigned BEFORE window extraction.
blocks=struct([]);
for k=1:nBlocks
    rng(seedBase+k,'twister');
    bits=uint8(randi([0 1],c.nSymbols+2*c.guard,4));
    tx=qam16(bits,'mod'); clean=cd_filter(tx,lengthKm,c);
    % Expected symbol energy is 1. SNR means Es/N0 in this discrete model.
    noise=sqrt(10^(-snrDb/10)/2)*(randn(size(tx))+1i*randn(size(tx)));
    blocks(k).tx=tx; blocks(k).rx=clean+noise;
    blocks(k).bits=bits; blocks(k).seed=seedBase+k;
    blocks(k).snrDb=snrDb; blocks(k).lengthKm=lengthKm;
    blocks(k).split=split;
end
end
