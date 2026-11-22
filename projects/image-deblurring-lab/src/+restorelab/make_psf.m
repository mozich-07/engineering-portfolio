function K = make_psf(p)
validateattributes(p.strength,{'numeric'},{'scalar','real','finite','positive'});
validateattributes(p.angle,{'numeric'},{'scalar','real','finite'});
if strcmp(p.kind,'gaussian')
    assert(p.strength<=5,'RestoreLab:Range','高斯 sigma 需在 (0,5] 范围。');
    n=2*ceil(3*p.strength)+1; K=fspecial('gaussian',n,p.strength);
elseif strcmp(p.kind,'motion')
    assert(p.strength>=1 && p.strength<=31,'RestoreLab:Range','运动长度需在 [1,31] 范围。');
    K=fspecial('motion',p.strength,p.angle);
else
    error('RestoreLab:Kind','未知模糊类型。');
end
K=K/sum(K(:));
end
