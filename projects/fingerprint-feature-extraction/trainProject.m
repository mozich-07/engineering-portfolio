function summary=trainProject
root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'src'));
summary=fp_train(root);
end
