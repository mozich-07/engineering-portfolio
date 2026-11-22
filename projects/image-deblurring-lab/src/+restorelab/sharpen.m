function S = sharpen(I,amount)
validateattributes(amount,{'numeric'},{'scalar','real','finite','>=',0,'<=',1.5});
% Unsharp mask, explicit and reproducible, same rule for all methods.
S=restorelab.clip(I+amount*(I-imgaussfilt(I,0.8,'Padding','symmetric')));
end
