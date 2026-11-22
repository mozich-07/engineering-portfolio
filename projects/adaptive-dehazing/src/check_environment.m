function check_environment(inputFolder)
%CHECK_ENVIRONMENT Verify the minimum runtime requirements.
if nargin < 1, inputFolder = 'haze_images'; end

if isdeployed,toolboxInfo=struct('Version','Runtime');else,toolboxInfo = ver('images');end
assert(~isempty(toolboxInfo), ...
    '未检测到 Image Processing Toolbox，请安装后再运行。');
assert(exist(inputFolder, 'dir') == 7, ...
    '缺少输入文件夹：%s', inputFolder);

patterns = {'*.jpg','*.jpeg','*.png','*.bmp','*.tif','*.tiff'};
imageCount = 0;
for i = 1:numel(patterns)
    imageCount = imageCount + numel(dir(fullfile(inputFolder, patterns{i})));
end
assert(imageCount > 0, 'haze_images 文件夹中没有支持的图片。');

fprintf('环境检查通过：MATLAB %s，Image Processing Toolbox %s。\n', ...
    version, toolboxInfo.Version);
fprintf('检测到 %d 张待处理雾图。\n', imageCount);
end
