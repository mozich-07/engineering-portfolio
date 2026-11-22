function cfg = setup_project()
% SETUP_PROJECT Add only project code, never modify the user's saved path.
root = fileparts(mfilename('fullpath'));
addpath(root);
addpath(fullfile(root,'src'));
addpath(fullfile(root,'tests'));
assert(exist('imfilter','file')==2 && exist('deconvwnr','file')==2, ...
    'RestoreLab:Toolbox','需要 Image Processing Toolbox。');
cfg = restorelab.config(root);
end
