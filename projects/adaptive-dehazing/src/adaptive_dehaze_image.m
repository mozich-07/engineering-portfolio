function result = adaptive_dehaze_image(inputImage, options)
%ADAPTIVE_DEHAZE_IMAGE Scene-aware Retinex/DCP image dehazing.
%   RESULT = ADAPTIVE_DEHAZE_IMAGE(I) returns the restored image and the
%   intermediate variables used to explain the algorithm. I can be uint8,
%   uint16, single or double, grayscale or RGB.
%
%   The method has two complementary branches:
%     1) edge-preserving multi-scale Retinex for illumination/detail;
%     2) dark-channel atmospheric inversion for dense haze.
%   A soft sky/smooth-region mask and an automatically estimated haze score
%   control pixel-wise fusion, reducing the common DCP dark-sky artefact.

if nargin < 2, options = struct(); end
cfg = defaultOptions(options);
validateattributes(inputImage, {'uint8','uint16','single','double','logical'}, ...
    {'nonempty','real','finite','nonsparse'},mfilename,'inputImage');
if ndims(inputImage)>3 || (~ismatrix(inputImage) && size(inputImage,3)~=3) ...
        || min(size(inputImage,1),size(inputImage,2))<3
    error('Dehaze:Input','请输入至少 3×3 的灰度图或 RGB 图。');
end
if isfloat(inputImage) && (min(inputImage(:))<0 || max(inputImage(:))>1)
    error('Dehaze:Range','浮点图像必须位于 [0,1]，请先使用 im2double。');
end
rgb = normalizeRgb(im2double(inputImage));
gray = rgb2gray(rgb);

[hazeScore, features, darkChannel] = estimateHaze(rgb, gray, cfg);
% A spatially constant image contains no recoverable structure. Retinex
% percentile normalization would otherwise invent a brightness change.
channelRange = squeeze(max(max(rgb,[],1),[],2)-min(min(rgb,[],1),[],2));
if all(channelRange < 1e-12)
    result = struct('input',rgb,'final',rgb,'retinex',rgb,'dcp',rgb, ...
        'hazeScore',hazeScore,'hazeLevel',hazeLabel(hazeScore), ...
        'sceneType','纯色或无纹理场景','features',features, ...
        'darkChannel',darkChannel,'transmissionRaw',ones(size(gray)), ...
        'transmission',ones(size(gray)),'illumination',max(rgb,[],3), ...
        'skyConfidence',zeros(size(gray)),'fusionWeight',zeros(size(gray)), ...
        'atmosphericLight',reshape(rgb(1,1,:),1,3), ...
        'options',cfg,'status','无可恢复纹理，保持输入');
    return;
end
skyConfidence = estimateSkyConfidence(rgb, gray, cfg);
[retinexImage, illumination] = retinexBranch(rgb, hazeScore, cfg);
[dcpImage, darkChannel, transmissionRaw, transmission, atmosphere] = ...
    dcpBranch(rgb, hazeScore, cfg, darkChannel);

% Dense haze and textured non-sky regions benefit more from DCP. Smooth,
% bright upper regions are protected by the Retinex branch.
gradientMap = imgradient(gray, 'sobel');
edgeConfidence = robustNormalize(gradientMap, 5, 95);
globalDcpWeight = 0.18 + 0.52 * hazeScore;
fusionWeight = globalDcpWeight .* (1 - cfg.skyProtection * skyConfidence) .* ...
    (0.78 + 0.22 * edgeConfidence);
fusionWeight = guidedSmooth(fusionWeight, gray, cfg.fusionRadius, 0.01);
fusionWeight = min(max(fusionWeight, 0.05), 0.78);

fused = retinexImage .* (1 - fusionWeight) + dcpImage .* fusionWeight;
restorationStrength = 0.52 + 0.38 * hazeScore;
restored = rgb .* (1 - restorationStrength) + fused .* restorationStrength;
restored = restrainedLocalContrast(restored, hazeScore, cfg);
restored = softGrayWorld(restored, 0.15 + 0.30 * hazeScore);
restored = min(max(restored, 0), 1);

skyRatio = mean(skyConfidence(:) > 0.45);
if skyRatio > 0.12
    sceneType = '室外/天空场景';
elseif features.meanBrightness < 0.34
    sceneType = '低照度场景';
else
    sceneType = '一般场景';
end

result.input = rgb;
result.final = restored;
result.retinex = retinexImage;
result.dcp = dcpImage;
result.hazeScore = hazeScore;
result.hazeLevel = hazeLabel(hazeScore);
result.sceneType = sceneType;
result.features = features;
result.darkChannel = darkChannel;
result.transmissionRaw = transmissionRaw;
result.transmission = transmission;
result.illumination = illumination;
result.skyConfidence = skyConfidence;
result.fusionWeight = fusionWeight;
result.atmosphericLight = atmosphere;
result.options = cfg;
result.status = '处理完成';
end

function cfg = defaultOptions(options)
cfg.retinxScales = [0.025 0.09 0.24];
cfg.retinexWeights = [0.25 0.50 0.25];
cfg.guidedRadius = 8;
cfg.fusionRadius = 10;
cfg.epsilon = 1e-6;
cfg.clipLimit = 0.006;
cfg.skyProtection = 0.78;
if ~isstruct(options) || ~isscalar(options)
    error('Dehaze:Options','options 必须是标量结构体。');
end
names = fieldnames(options);
for i = 1:numel(names)
    if ~isfield(cfg,names{i}) && ~strcmp(names{i},'darkPatchSize')
        error('Dehaze:Options','未知参数：%s',names{i});
    end
    cfg.(names{i}) = options.(names{i});
end
validateattributes(cfg.retinxScales,{'numeric'},{'vector','nonempty','real','finite','positive','<=',1});
validateattributes(cfg.retinexWeights,{'numeric'},{'vector','nonempty','real','finite','nonnegative'});
if numel(cfg.retinxScales)~=numel(cfg.retinexWeights) || abs(sum(cfg.retinexWeights)-1)>1e-9
    error('Dehaze:Options','Retinex 尺度与权重必须等长，权重之和须为 1。');
end
validateattributes(cfg.guidedRadius,{'numeric'},{'scalar','integer','>=',1,'<=',100});
validateattributes(cfg.fusionRadius,{'numeric'},{'scalar','integer','>=',1,'<=',100});
validateattributes(cfg.epsilon,{'numeric'},{'scalar','real','finite','positive','<=',0.01});
validateattributes(cfg.clipLimit,{'numeric'},{'scalar','real','finite','>',0,'<=',1});
validateattributes(cfg.skyProtection,{'numeric'},{'scalar','real','finite','>=',0,'<=',1});
if isfield(cfg,'darkPatchSize')
    validateattributes(cfg.darkPatchSize,{'numeric'},{'scalar','integer','>=',3,'<=',101});
end
end

function rgb = normalizeRgb(image)
if ismatrix(image)
    rgb = repmat(image, 1, 1, 3);
elseif size(image, 3) >= 3
    rgb = image(:, :, 1:3);
else
    error('adaptive_dehaze_image:UnsupportedImage', '不支持该图像通道数。');
end
rgb(~isfinite(rgb)) = 0;
rgb = min(max(rgb, 0), 1);
end

function [score, f, dark] = estimateHaze(rgb, gray, cfg)
dark = localDarkChannel(rgb, cfg);
hsvImage = rgb2hsv(rgb);
f.luminanceSpread = prctile(gray(:), 95) - prctile(gray(:), 5);
f.meanDarkChannel = mean(dark(:));
f.meanSaturation = mean(hsvImage(:, :, 2), 'all');
f.meanBrightness = mean(gray(:));
contrastCue = min(max((0.58 - f.luminanceSpread) / 0.48, 0), 1);
darkCue = min(max((f.meanDarkChannel - 0.08) / 0.55, 0), 1);
desaturationCue = min(max((0.48 - f.meanSaturation) / 0.42, 0), 1);
score = 0.46 * contrastCue + 0.37 * darkCue + 0.17 * desaturationCue;
score = min(max(score, 0), 1);
end

function label = hazeLabel(score)
if score < 0.34
    label = '轻雾';
elseif score < 0.67
    label = '中雾';
else
    label = '浓雾';
end
end

function dark = localDarkChannel(rgb, cfg)
patch = max(7, min(25, 2 * floor(min(size(rgb, 1), size(rgb, 2)) / 90) + 1));
dark = imerode(min(rgb, [], 3), strel('square', patch));
if nargin > 1 && isfield(cfg, 'darkPatchSize')
    patch = max(3, 2 * floor(cfg.darkPatchSize / 2) + 1);
    dark = imerode(min(rgb, [], 3), strel('square', patch));
end
end

function sky = estimateSkyConfidence(rgb, gray, cfg)
[height, width, ~] = size(rgb);
hsvImage = rgb2hsv(rgb);
saturation = hsvImage(:, :, 2);
brightness = hsvImage(:, :, 3);
gradientMap = imgradient(gray, 'sobel');
gradientScale = prctile(gradientMap(:), 80) + cfg.epsilon;
smoothness = exp(-gradientMap / gradientScale);
[y, ~] = ndgrid(linspace(0, 1, height), 1:width);
upperPrior = max(0, 1 - y / 0.72) .^ 0.7;
brightCue = min(max((brightness - 0.42) / 0.40, 0), 1);
lowSaturationCue = min(max((0.38 - saturation) / 0.32, 0), 1);
blueCue = min(max((rgb(:, :, 3) - rgb(:, :, 1) + 0.08) / 0.22, 0), 1);
sky = upperPrior .* smoothness .* brightCue .* ...
    (0.65 * lowSaturationCue + 0.35 * blueCue);
sky = imgaussfilt(sky, max(1, round(min(height, width) / 180)), ...
    'Padding', 'replicate');
sky = min(max(sky, 0), 1);
end

function [output, illumination] = retinexBranch(rgb, hazeScore, cfg)
hsvImage = rgb2hsv(rgb);
value = hsvImage(:, :, 3);
responseFine = zeros(size(value));
responseGuided = zeros(size(value));
illumination = zeros(size(value));
for i = 1:numel(cfg.retinxScales)
    sigma = max(1, round(min(size(value)) * cfg.retinxScales(i)));
    base = imgaussfilt(value, sigma, 'Padding', 'replicate');
    smoothBase = guidedSmooth(base, value, cfg.guidedRadius, 0.008);
    responseFine = responseFine + cfg.retinexWeights(i) .* ...
        (log(value + cfg.epsilon) - log(base + cfg.epsilon));
    responseGuided = responseGuided + cfg.retinexWeights(i) .* ...
        (log(value + cfg.epsilon) - log(smoothBase + cfg.epsilon));
    illumination = illumination + cfg.retinexWeights(i) .* smoothBase;
end
response = 0.78 * responseFine + 0.22 * responseGuided;
newValue = robustNormalize(response, 1, 99);
local = adapthisteq(newValue, 'NumTiles', tileCount(newValue), ...
    'ClipLimit', min(0.012, cfg.clipLimit * (0.75 + 0.55 * hazeScore)));
newValue = (0.88 - 0.10 * hazeScore) * newValue + ...
    (0.12 + 0.10 * hazeScore) * local;
detail = newValue - imgaussfilt(newValue, 1.0, 'Padding', 'replicate');
detail = sign(detail) .* max(abs(detail) - 0.012, 0);
newValue = min(max(newValue + 0.22 * detail, 0), 1);
hsvImage(:, :, 2) = min(hsvImage(:, :, 2) .* ...
    (1 + 0.14 * hazeScore .* (1 - hsvImage(:, :, 2))), 0.96);
hsvImage(:, :, 3) = newValue;
output = hsv2rgb(hsvImage);
output = min(max(output, 0), 1);
end

function [output, dark, rawTransmission, transmission, atmosphere] = ...
        dcpBranch(rgb, hazeScore, cfg, dark)
[~, order] = sort(dark(:), 'descend');
topCount = max(1, round(0.001 * numel(dark)));
pixels = reshape(rgb, [], 3);
candidates = pixels(order(1:topCount), :);
[~, index] = max(sum(candidates, 2));
atmosphere = min(max(candidates(index, :), 0.55), 0.98);
normalized = rgb ./ reshape(max(atmosphere, cfg.epsilon), 1, 1, 3);
omega = 0.84 + 0.10 * hazeScore;
rawTransmission = 1 - omega * localDarkChannel(normalized, cfg);
transmission = guidedSmooth(rawTransmission, rgb2gray(rgb), ...
    max(12, cfg.guidedRadius * 2), 0.0015);
floorValue = 0.22 - 0.07 * hazeScore;
transmission = min(max(transmission, floorValue), 1);
output = (rgb - reshape(atmosphere, 1, 1, 3)) ./ transmission + ...
    reshape(atmosphere, 1, 1, 3);
output = min(max(output, 0), 1);
end

function output = restrainedLocalContrast(rgb, hazeScore, cfg)
hsvImage = rgb2hsv(rgb);
value = hsvImage(:, :, 3);
local = adapthisteq(value, 'NumTiles', tileCount(value), ...
    'ClipLimit', min(0.010, cfg.clipLimit * (0.65 + 0.55 * hazeScore)));
strength = 0.05 + 0.10 * hazeScore;
hsvImage(:, :, 3) = (1 - strength) * value + strength * local;
output = hsv2rgb(hsvImage);
end

function output = softGrayWorld(rgb, strength)
channelMean = squeeze(mean(mean(rgb, 1), 2));
target = mean(channelMean);
gain = target ./ max(channelMean, 1e-4);
gain = min(max(gain, 0.88), 1.12);
gain = 1 + strength * (gain - 1);
output = rgb .* reshape(gain, 1, 1, 3);
end

function q = guidedSmooth(input, guide, radius, epsValue)
radius = min(radius, floor((min(size(input))-2)/2));
if radius<1, q=input; return; end
if exist('imguidedfilter', 'file') == 2
    side = 2 * radius + 1;
    q = imguidedfilter(input, guide, 'NeighborhoodSize', [side side], ...
        'DegreeOfSmoothing', epsValue);
    return;
end

kernel = ones(2 * radius + 1) / (2 * radius + 1)^2;
meanGuide = imfilter(guide, kernel, 'replicate');
meanInput = imfilter(input, kernel, 'replicate');
correlation = imfilter(guide .* input, kernel, 'replicate');
variance = imfilter(guide .* guide, kernel, 'replicate') - meanGuide .^ 2;
covariance = correlation - meanGuide .* meanInput;
a = covariance ./ (variance + epsValue);
b = meanInput - a .* meanGuide;
q = imfilter(a, kernel, 'replicate') .* guide + ...
    imfilter(b, kernel, 'replicate');
end

function count = tileCount(image)
count = max([2 2], min([8 8], floor(size(image)/2)));
end

function value = robustNormalize(image, lowPercent, highPercent)
bounds = prctile(image(:), [lowPercent highPercent]);
if bounds(2) <= bounds(1) + eps
    value = mat2gray(image);
else
    value = (image - bounds(1)) / (bounds(2) - bounds(1));
end
value = min(max(value, 0), 1);
end
