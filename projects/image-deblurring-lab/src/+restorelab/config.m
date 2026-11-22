function c = config(root)
c.root = root;
c.seed = 20261015;
c.imageSize = 192;
c.counts = [36 12 12];
c.noiseLevels = [0.005 0.015];
c.lambdas = [1e-5 1e-4 1e-3 1e-2 0.1 1];
c.blends = [0.5 1];
c.sharpAmounts = [0 0.15 0.3];
c.patchRadius = 2;
c.trainPixels = 800;
c.naturalPixels = 4000;
c.metricBorder = 12;
c.modelPath = fullfile(root,'models','restoration_model.mat');
c.manifestPath = fullfile(root,'data','manifest.csv');
c.cases = struct('name',{},'kind',{},'strength',{},'angle',{});
names = {'gaussian_09','gaussian_15','gaussian_20','motion_5_0','motion_7_45','motion_9_90'};
for j=1:6
    if j<=3
        kind='gaussian'; v=[0.9 1.5 2]; s=v(j); a=0;
    else
        kind='motion'; v=[5 7 9]; a0=[0 45 90]; s=v(j-3); a=a0(j-3);
    end
    c.cases(j)=struct('name',names{j},'kind',kind,'strength',s,'angle',a);
end
end
