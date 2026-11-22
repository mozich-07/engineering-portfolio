function result = demo()
% Run the scene-aware algorithm on the credited lake photograph.
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'src'));
result = adaptive_dehaze_image(imread(fullfile(root, 'assets', 'lake-fog.jpg')));
if nargout == 0
    montage({result.input, result.final}, 'Size', [1 2]);
    title('Input / Adaptive fusion');
end
end
