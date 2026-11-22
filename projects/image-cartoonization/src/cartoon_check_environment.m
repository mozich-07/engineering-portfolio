function cartoon_check_environment()
if verLessThan('matlab','9.10'), error('Cartoon:Version','需要 MATLAB R2021a 或更新版本。'); end
required={'imbilatfilt','rgb2lab','lab2rgb','rgb2ind','edge','imgaussfilt','bwareaopen','imresize'};
for k=1:numel(required)
    if isempty(which(required{k})), error('Cartoon:Toolbox','需要 Image Processing Toolbox。'); end
end
if ~license('test','image_toolbox'), error('Cartoon:License','Image Processing Toolbox 许可证不可用。'); end
end
