function root = setup_project()
root = fileparts(mfilename('fullpath'));
addpath(root, fullfile(root,'third_party','frangi'));
end
