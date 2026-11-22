function benchmarkTable = run_synthetic_benchmark(clearFolder, outputFolder)
%RUN_SYNTHETIC_BENCHMARK Paired, reproducible quantitative validation.
%   Clear images are converted to light/medium/dense synthetic haze using
%   I(x)=J(x)t(x)+A(1-t(x)). Because J is known, PSNR and SSIM can be used.

if nargin < 1 || isempty(clearFolder), clearFolder = 'clear_images'; end
if nargin < 2 || isempty(outputFolder)
    outputFolder = fullfile('results', 'synthetic_benchmark');
end
assert(exist(clearFolder, 'dir') == 7, '清晰图文件夹不存在：%s', clearFolder);
if exist(outputFolder, 'dir') ~= 7, mkdir(outputFolder); end
compareFolder = fullfile(outputFolder, 'comparison');
if exist(compareFolder, 'dir') ~= 7, mkdir(compareFolder); end

files = listImages(clearFolder);
assert(~isempty(files), 'clear_images 中没有图像。');
betaLevels = [0.55 1.00 1.55];
levelNames = {'轻雾','中雾','浓雾'};
rows = cell(numel(files) * numel(betaLevels), 13);
row = 0;
rng(20260920, 'twister');

for k = 1:numel(files)
    clearImage = normalizeRgb(im2double(imread(fullfile(files(k).folder, files(k).name))));
    depth = syntheticDepth(size(clearImage, 1), size(clearImage, 2));
    for j = 1:numel(betaLevels)
        row = row + 1;
        beta = betaLevels(j);
        transmission = exp(-beta * depth);
        atmosphere = reshape([0.88 0.92 0.98], 1, 1, 3);
        hazy = clearImage .* transmission + atmosphere .* (1 - transmission);
        result = adaptive_dehaze_image(hazy);

        qInput = pairedMetrics(hazy, clearImage);
        qRetinex = pairedMetrics(result.retinex, clearImage);
        qDcp = pairedMetrics(result.dcp, clearImage);
        qAdaptive = pairedMetrics(result.final, clearImage);
        rows(row, :) = {files(k).name, levelNames{j}, beta, result.hazeScore, ...
            qInput.psnr, qRetinex.psnr, qDcp.psnr, qAdaptive.psnr, ...
            qInput.ssim, qRetinex.ssim, qDcp.ssim, qAdaptive.ssim, ...
            qAdaptive.psnr - qInput.psnr};

        [~, baseName] = fileparts(files(k).name);
        saveBenchmarkFigure(clearImage, hazy, result, transmission, ...
            levelNames{j}, qInput, qAdaptive, fullfile(compareFolder, ...
            sprintf('%s_%02d_%s.png', baseName, j, levelNames{j})));
        fprintf('%s / %s：PSNR %.2f -> %.2f dB，SSIM %.3f -> %.3f\n', ...
            files(k).name, levelNames{j}, qInput.psnr, qAdaptive.psnr, ...
            qInput.ssim, qAdaptive.ssim);
    end
end

variableNames = {'file','synthetic_haze_level','beta','estimated_haze_score', ...
    'psnr_input','psnr_retinex','psnr_dcp','psnr_adaptive','ssim_input', ...
    'ssim_retinex','ssim_dcp','ssim_adaptive','psnr_gain_adaptive'};
benchmarkTable = cell2table(rows, 'VariableNames', variableNames);
writetable(benchmarkTable, fullfile(outputFolder, 'paired_metrics.csv'));
saveBenchmarkSummary(benchmarkTable, fullfile(outputFolder, 'benchmark_summary.png'));
end

function files = listImages(folder)
patterns = {'*.jpg','*.jpeg','*.png','*.bmp','*.tif','*.tiff'};
files = [];
for i = 1:numel(patterns)
    files = [files; dir(fullfile(folder, patterns{i}))]; %#ok<AGROW>
end
end

function rgb = normalizeRgb(image)
if ismatrix(image)
    rgb = repmat(image, 1, 1, 3);
else
    rgb = image(:, :, 1:3);
end
rgb = min(max(rgb, 0), 1);
end

function depth = syntheticDepth(height, width)
% A smooth upper-distance prior plus low-frequency irregular structure.
[y, x] = ndgrid(linspace(0, 1, height), linspace(0, 1, width));
vertical = 0.20 + 0.80 * (1 - y) .^ 0.85;
radial = 0.18 * sqrt((x - 0.52).^2 + (y - 0.82).^2);
noiseSmall = imgaussfilt(rand(48, 64), 3.5, 'Padding', 'replicate');
noiseLarge = imresize(noiseSmall, [height width], 'bicubic');
noiseLarge = (noiseLarge - min(noiseLarge(:))) / ...
    max(max(noiseLarge(:)) - min(noiseLarge(:)), eps);
depth = vertical + radial + 0.18 * (noiseLarge - 0.5);
depth = 0.18 + 0.82 * mat2gray(depth);
end

function q = pairedMetrics(image, reference)
q.psnr = psnr(image, reference);
q.ssim = ssim(rgb2gray(image), rgb2gray(reference));
end

function saveBenchmarkFigure(clearImage, hazy, r, transmission, levelName, q0, q1, targetPath)
figure('Visible','off','Color','w','Position',[100 100 1500 850]);
tiledlayout(2, 3, 'Padding','compact','TileSpacing','compact');
showTile(clearImage, '清晰真值');
showTile(hazy, sprintf('合成%s', levelName));
nexttile; imshow(transmission, []); title('合成透射率真值','FontWeight','bold'); colorbar;
showTile(r.retinex, 'Retinex 分支');
showTile(r.dcp, 'DCP 分支');
showTile(r.final, sprintf('自适应融合\nPSNR %.2f→%.2f dB  SSIM %.3f→%.3f', ...
    q0.psnr, q1.psnr, q0.ssim, q1.ssim));
exportgraphics(gcf, targetPath, 'Resolution', 180); close(gcf);
end

function showTile(image, label)
nexttile; imshow(image); title(label,'FontWeight','bold');
end

function saveBenchmarkSummary(t, targetPath)
levels = unique(t.synthetic_haze_level, 'stable');
psnrValues = zeros(numel(levels), 4);
ssimValues = zeros(numel(levels), 4);
for i = 1:numel(levels)
    selected = strcmp(t.synthetic_haze_level, levels{i});
    psnrValues(i, :) = [mean(t.psnr_input(selected)), mean(t.psnr_retinex(selected)), ...
        mean(t.psnr_dcp(selected)), mean(t.psnr_adaptive(selected))];
    ssimValues(i, :) = [mean(t.ssim_input(selected)), mean(t.ssim_retinex(selected)), ...
        mean(t.ssim_dcp(selected)), mean(t.ssim_adaptive(selected))];
end
figure('Visible','off','Color','w','Position',[100 100 1400 600]);
tiledlayout(1, 2, 'Padding','compact','TileSpacing','compact');
nexttile; bar(psnrValues); grid on; title('配对实验 PSNR'); ylabel('dB');
set(gca,'XTickLabel',levels); legend('输入雾图','Retinex','DCP','自适应融合','Location','best');
nexttile; bar(ssimValues); grid on; title('配对实验 SSIM'); ylabel('SSIM'); ylim([0 1]);
set(gca,'XTickLabel',levels); legend('输入雾图','Retinex','DCP','自适应融合','Location','best');
sgtitle('可重复的合成雾定量验证','FontSize',16,'FontWeight','bold');
exportgraphics(gcf, targetPath, 'Resolution', 180); close(gcf);
end
