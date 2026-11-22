function demo
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root,'src'));
input = imread(fullfile(root,'..','..','collections','electronics','assets','signal-generator.jpg'));
reference = im2double(imresize(input,[300 NaN]));
hazy = synthesize_haze(reference,1.25,17,'nonuniform');
r = dehaze_v2(hazy);
separator = ones(size(reference,1),5,3);
strip = [reference separator hazy separator r.final];
imshow(strip);
imwrite(strip,fullfile(root,'assets','controlled-example.jpg'),'Quality',90);
end
