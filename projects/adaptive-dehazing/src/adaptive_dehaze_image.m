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
rgb = normalizeRgb(im2double(inputImage));
gray = rgb2gray(rgb);

[hazeScore, features] = estimateHaze(rgb, gray, cfg);
skyConfidence = estimateSkyConfidence(rgb, gray, cfg);
[retinexImage, illumination] = retinexBranch(rgb, hazeScore, cfg);
[dcpImage, darkChannel, transmissionRaw, transmission, atmosphere] = ...
    dcpBranch(rgb, hazeScore, cfg);

% Dense haze and textured non-sky regions benefit more from DCP. Smooth,
% bright upper regions are protected by the Retinex branch.
gradientMap = imgradient(gray, 'sobel');
edgeConfidence = robustNormalize(gradientMap, 5, 95);
globalDcpWeight = 0.18 + 0.52 * hazeScore;
fusionWeight = globalDcpWeight .* (1 - 0.78 * skyConfidence) .* ...
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
end

function cfg = defaultOptions(options)
cfg.retinxScales = [0.025 0.09 0.24];
cfg.retinexWeights = [0.25 0.50 0.25];
cfg.guidedRadius = 8;
cfg.fusionRadius = 10;
cfg.epsilon = 1e-6;
cfg.clipLimit = 0.006;
names = fieldnames(options);
for i = 1:numel(names)
    cfg.(names{i}) = options.(names{i});
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

function [score, f] = estimateHaze(rgb, gray, cfg)
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
local = adapthisteq(newValue, 'NumTiles', [8 8], ...
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
        dcpBranch(rgb, hazeScore, cfg)
dark = localDarkChannel(rgb, cfg);
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
local = adapthisteq(value, 'NumTiles', [8 8], ...
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

function value = robustNormalize(image, lowPercent, highPercent)
bounds = prctile(image(:), [lowPercent highPercent]);
if bounds(2) <= bounds(1) + eps
    value = mat2gray(image);
else
    value = (image - bounds(1)) / (bounds(2) - bounds(1));
end
value = min(max(value, 0), 1);
end
