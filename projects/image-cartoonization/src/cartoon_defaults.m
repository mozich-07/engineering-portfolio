function p = cartoon_defaults(name)
%CARTOON_DEFAULTS 四组有实际区别的数字图像处理预设。
if nargin<1, name='natural'; end
p=struct('Preset',char(name),'Colors',48,'SmoothStrength',0.50,'SmoothPasses',2, ...
    'EdgeDetail',0.15,'InkStrength',0.45,'Saturation',1.06, ...
    'ColorBlend',0.45,'LineWidth',1,'MaxDimension',1280,'Mode','color');
switch char(name)
    case 'natural'
    case 'comic'
        p.Colors=24;p.SmoothStrength=.70;p.EdgeDetail=.55;p.InkStrength=.90;p.Saturation=1.16;p.ColorBlend=.10;
    case 'poster'
        p.Colors=12;p.SmoothStrength=.75;p.EdgeDetail=.25;p.InkStrength=.55;p.Saturation=1.20;p.ColorBlend=0;
    case 'sketch'
        p.Mode='sketch';p.EdgeDetail=.65;p.InkStrength=1;p.SmoothStrength=.50;
    otherwise
        error('Cartoon:Preset','未知风格。');
end
end
