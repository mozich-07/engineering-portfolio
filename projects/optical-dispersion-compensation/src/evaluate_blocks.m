function [summary,perBlock,example] = evaluate_blocks(blocks,model,c)
% EVALUATE_BLOCKS Shared noise realization, identical centers, four methods.
names={'Uncompensated','Fixed60km','RidgeML','OracleCD'};
allZ=cell(1,4); allT=[]; allBits=[]; rows={}; example=struct();
ix=c.guard+(1:c.nSymbols);
for b=1:numel(blocks)
    block=blocks(b); [X,Y,bt]=window_features(block,model.K,c);
    target=Y(:,1)+1i*Y(:,2);
    fixed=cd_filter(block.rx,-c.assumedLengthKm,c);
    oracle=cd_filter(block.rx,-block.lengthKm,c);
    Z={block.rx(ix),fixed(ix),predict_ridge(model,X),oracle(ix)};
    for j=1:4
        z=Z{j}(:); allZ{j}=[allZ{j};z]; %#ok<AGROW>
        m=signal_metrics(z,target,bt);
        rows(end+1,:)={block.seed,block.lengthKm,block.snrDb,names{j},m.errors,m.nBits,m.BER,m.EVM}; %#ok<AGROW>
    end
    allT=[allT;target]; allBits=[allBits;bt]; %#ok<AGROW>
    if b==1
        example.tx=target; example.rx=Z{1}; example.fixed=Z{2};
        example.ml=Z{3}; example.oracle=Z{4}; example.snrDb=block.snrDb;
        example.lengthKm=block.lengthKm;
    end
end
out={};
for j=1:4
    m=signal_metrics(allZ{j},allT,allBits);
    blockBers=cell2mat(rows(j:4:end,7));
    % Independent block mean standard-error interval (normal approximation).
    se=std(blockBers)/sqrt(numel(blocks));
    out(j,:)={blocks(1).lengthKm,blocks(1).snrDb,names{j},m.errors,m.nBits, ...
        m.BER,m.SER,m.EVM,m.NMSE,m.ciLow,m.ciHigh,max(0,m.BER-1.96*se),min(1,m.BER+1.96*se)};
end
summary=cell2table(out,'VariableNames',{'LengthKm','SNRdB','Method','BitErrors','TotalBits', ...
    'BER','SER','EVMpercent','NMSE','WilsonLow','WilsonHigh','BlockCILow','BlockCIHigh'});
perBlock=cell2table(rows,'VariableNames',{'Seed','LengthKm','SNRdB','Method','BitErrors','TotalBits','BER','EVMpercent'});
end
