function start_here
root=fileparts(mfilename('fullpath'));addpath(root);
assert(exist('imguidedfilter','file')==2,'需要 Image Processing Toolbox。');
dehaze_studio;
end
