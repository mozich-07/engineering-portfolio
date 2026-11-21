% Recalculate screening and segmentation scores from archived test results.
root = fileparts(mfilename('fullpath'));
screen = readtable(fullfile(root,'results','classification_summary.csv'));
test = screen(strcmp(screen.Split,'test'),:);
test.RecomputedF1 = 2*test.TP ./ (2*test.TP + test.FP + test.FN);
assert(all(abs(test.F1-test.RecomputedF1)<1e-10));
disp(test(:,{'Method','SourceImages','Patches','F1'}));

images = readtable(fullfile(root,'results','test_per_image.csv'));
summary = readtable(fullfile(root,'results','test_summary.csv'));
for k = 1:height(summary)
    rows = images(strcmp(images.Method,summary.Method{k}),:);
    assert(height(rows)==summary.Images(k));
    perImageIoU = rows.TP ./ (rows.TP+rows.FP+rows.FN);
    assert(abs(mean(perImageIoU)-summary.MeanIoU(k))<1e-10);
end
disp(summary(:,{'Method','Images','MeanIoU','MicroIoU'}));
example = crack.metrics([1 1 0],[1 0 1]);
assert(example.TP==1 && example.FP==1 && example.FN==1);
