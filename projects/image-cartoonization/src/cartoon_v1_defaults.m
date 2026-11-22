function p = cartoon_v1_defaults(name)
%CARTOON_DEFAULTS 固定参数，无随机初始化，便于重复演示。
if nargin < 1, name = 'standard'; end
p = struct('Colors',24,'SmoothPasses',2,'EdgeThreshold',0.18, ...
    'EdgeSigma',1.4,'LineWidth',1,'MaxDimension',1000,'Mode','color');
switch char(name)
    case 'soft'
        p.Colors=48; p.SmoothPasses=2; p.EdgeThreshold=0.24;
    case 'strong'
        p.Colors=12; p.SmoothPasses=3; p.EdgeThreshold=0.15; p.LineWidth=2;
    case 'sketch'
        p.Mode='sketch'; p.EdgeThreshold=0.15;
    case 'standard'
    otherwise
        error('Cartoon:Preset','未知预设。');
end
end
