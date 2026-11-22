function metricsTable = run_adaptive_dehaze_system(inputFolder, outputFolder)
%RUN_ADAPTIVE_DEHAZE_SYSTEM Batch runner for the enhanced course project.
%   It exports final images, method comparisons, interpretable intermediate
%   maps, a per-image CSV and an aggregate summary chart.

if nargin < 1 || isempty(inputFolder), inputFolder = 'haze_images'; end
if nargin < 2 || isempty(outputFolder), outputFolder = 'results'; end
assert(exist(inputFolder, 'dir') == 7, '输入文件夹不存在：%s', inputFolder);

folders.final = fullfile(outputFolder, 'final');
folders.comparison = fullfile(outputFolder, 'comparison');
folders.diagnostics = fullfile(outputFolder, 'diagnostics');
names = fieldnames(folders);
for i = 1:numel(names)
    if exist(folders.(names{i}), 'dir') ~= 7, mkdir(folders.(names{i})); end
end

files = listImages(inputFolder);
assert(~isempty(files), '输入文件夹中没有支持的图像。');
rows = cell(numel(files), 20);

fprintf('自适应去雾系统：共 %d 张图像\n', numel(files));
for k = 1:numel(files)
    tic;
    sourcePath = fullfile(files(k).folder, files(k).name);
    inputImage = imread(sourcePath);
    result = adaptive_dehaze_image(inputImage);
    elapsed = toc;
    [~, baseName] = fileparts(files(k).name);
    imwrite(result.final, fullfile(folders.final, [baseName '_adaptive.png']));
    saveComparison(result, fullfile(folders.comparison, ...
        [baseName '_comparison.png']));
    saveDiagnostics(result, fullfile(folders.diagnostics, ...
        [baseName '_diagnostics.png']));

    inputMetric = qualityMetrics(result.input);
    retinexMetric = qualityMetrics(result.retinex);
    dcpMetric = qualityMetrics(result.dcp);
    finalMetric = qualityMetrics(result.final);
    rows(k, :) = {files(k).name, result.sceneType, result.hazeLevel, ...
        result.hazeScore, mean(result.transmission(:)), ...
        mean(result.skyConfidence(:) > 0.45), mean(result.fusionWeight(:)), ...
        inputMetric.entropy, retinexMetric.entropy, dcpMetric.entropy, ...
        finalMetric.entropy, inputMetric.gradient, retinexMetric.gradient, ...
        dcpMetric.gradient, finalMetric.gradient, inputMetric.contrast, ...
        finalMetric.contrast, inputMetric.colorfulness, ...
        finalMetric.colorfulness, elapsed};
    fprintf('[%d/%d] %-18s  %s / %s  雾度=%.3f  %.2fs\n', ...
        k, numel(files), files(k).name, result.sceneType, result.hazeLevel, ...
        result.hazeScore, elapsed);
end

variableNames = {'file','scene_type','haze_level','haze_score', ...
    'mean_transmission','sky_ratio','mean_dcp_weight','entropy_input', ...
    'entropy_retinex','entropy_dcp','entropy_adaptive','gradient_input', ...
    'gradient_retinex','gradient_dcp','gradient_adaptive','contrast_input', ...
    'contrast_adaptive','colorfulness_input','colorfulness_adaptive','runtime_s'};
metricsTable = cell2table(rows, 'VariableNames', variableNames);
writetable(metricsTable, fullfile(outputFolder, 'adaptive_metrics.csv'));
saveSummary(metricsTable, fullfile(outputFolder, 'batch_summary.png'));
saveMethodSummary(metricsTable, fullfile(outputFolder, 'method_summary.csv'));
fprintf('处理完成：%s\n', outputFolder);
end

function files = listImages(folder)
patterns = {'*.jpg','*.jpeg','*.png','*.bmp','*.tif','*.tiff'};
files = [];
for i = 1:numel(patterns)
    files = [files; dir(fullfile(folder, patterns{i}))]; %#ok<AGROW>
end
[~, order] = sort(lower({files.name}));
files = files(order);
end

function m = qualityMetrics(rgb)
gray = rgb2gray(rgb);
m.entropy = entropy(gray);
[gx, gy] = gradient(gray);
m.gradient = mean(hypot(gx(:), gy(:)));
m.contrast = std(gray(:));
rg = rgb(:, :, 1) - rgb(:, :, 2);
yb = 0.5 * (rgb(:, :, 1) + rgb(:, :, 2)) - rgb(:, :, 3);
m.colorfulness = sqrt(std(rg(:))^2 + std(yb(:))^2) + ...
    0.3 * sqrt(mean(rg(:))^2 + mean(yb(:))^2);
end

function saveComparison(r, targetPath)
figure('Visible','off','Color','w','Position',[100 100 1600 900]);
tiledlayout(2, 3, 'Padding','compact','TileSpacing','compact');
showTile(r.input, '输入雾图');
showTile(r.retinex, 'Retinex 分支');
showTile(r.dcp, 'DCP 大气模型分支');
nexttile; imagesc(r.fusionWeight, [0 1]); axis image off; colormap(gca, turbo);
title('自适应 DCP 权重图','FontWeight','bold'); colorbar;
showTile(r.final, '场景感知融合结果');
nexttile; axis off;
text(0.03, 0.88, sprintf('场景：%s', r.sceneType), 'FontSize',15,'FontWeight','bold');
text(0.03, 0.70, sprintf('雾等级：%s', r.hazeLevel), 'FontSize',14);
text(0.03, 0.56, sprintf('雾度分数：%.3f', r.hazeScore), 'FontSize',14);
text(0.03, 0.42, sprintf('平均透射率：%.3f', mean(r.transmission(:))), 'FontSize',14);
text(0.03, 0.28, sprintf('平均 DCP 权重：%.3f', mean(r.fusionWeight(:))), 'FontSize',14);
text(0.03, 0.10, '自动分析 → 分支恢复 → 区域融合', 'FontSize',13,'Color',[0.1 0.35 0.65]);
exportgraphics(gcf, targetPath, 'Resolution', 180); close(gcf);
end

function saveDiagnostics(r, targetPath)
figure('Visible','off','Color','w','Position',[100 100 1500 900]);
tiledlayout(2, 4, 'Padding','compact','TileSpacing','compact');
showTile(r.input, '输入');
nexttile; imshow(r.darkChannel, []); title('暗通道','FontWeight','bold');
nexttile; imshow(r.transmissionRaw, []); title('初始透射率','FontWeight','bold');
nexttile; imshow(r.transmission, []); title('引导滤波透射率','FontWeight','bold');
nexttile; imshow(r.illumination, []); title('Retinex 光照分量','FontWeight','bold');
nexttile; imshow(r.skyConfidence, []); title('天空/平滑区置信度','FontWeight','bold');
nexttile; imshow(r.fusionWeight, []); title('DCP 融合权重','FontWeight','bold');
showTile(r.final, '最终结果');
exportgraphics(gcf, targetPath, 'Resolution', 180); close(gcf);
end

function showTile(image, label)
nexttile; imshow(image); title(label,'FontWeight','bold');
end

function saveSummary(t, targetPath)
count = height(t); x = 1:count;
figure('Visible','off','Color','w','Position',[100 100 1500 850]);
tiledlayout(2, 2, 'Padding','compact','TileSpacing','compact');
nexttile; bar(x, t.haze_score, 0.72, 'FaceColor',[0.25 0.55 0.85]);
yline(0.34,'--'); yline(0.67,'--'); ylim([0 1]); grid on;
title('自动雾度评估'); xlabel('图像编号'); ylabel('雾度分数');
nexttile; bar([t.entropy_input t.entropy_adaptive]); grid on;
title('信息熵对比'); xlabel('图像编号'); ylabel('bit'); legend('输入','自适应方法','Location','best');
nexttile; bar([t.gradient_input t.gradient_adaptive]); grid on;
title('平均梯度对比'); xlabel('图像编号'); ylabel('平均梯度'); legend('输入','自适应方法','Location','best');
nexttile; bar([t.contrast_input t.contrast_adaptive]); grid on;
title('RMS 对比度'); xlabel('图像编号'); ylabel('标准差'); legend('输入','自适应方法','Location','best');
sgtitle(sprintf('批处理汇总（%d 张图像）', count),'FontSize',16,'FontWeight','bold');
exportgraphics(gcf, targetPath, 'Resolution', 180); close(gcf);
end

function saveMethodSummary(t, targetPath)
method = {'输入';'Retinex';'DCP';'自适应融合'};
meanEntropy = [mean(t.entropy_input); mean(t.entropy_retinex); ...
    mean(t.entropy_dcp); mean(t.entropy_adaptive)];
meanGradient = [mean(t.gradient_input); mean(t.gradient_retinex); ...
    mean(t.gradient_dcp); mean(t.gradient_adaptive)];
summary = table(method, meanEntropy, meanGradient, ...
    'VariableNames', {'method','mean_entropy','mean_gradient'});
writetable(summary, targetPath);
end
