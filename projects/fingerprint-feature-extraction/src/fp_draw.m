function fp_draw(ax,R,stage)
cla(ax);hold(ax,'off');
switch stage
    case 'original', imshow(R.original,'Parent',ax);title(ax,'输入图像');
    case 'enhanced', imshow(R.enhanced,'Parent',ax);title(ax,'方向滤波增强');
    case 'binary', imshow(R.binary,'Parent',ax);title(ax,'脊线二值化');
    case 'skeleton', imshow(~R.skeleton,'Parent',ax);title(ax,'单像素骨架');
    case 'quality'
        imshow(repmat(R.original,1,1,3),'Parent',ax);hold(ax,'on');
        h=imagesc(ax,R.quality,[0 1]);h.AlphaData=0.6*R.mask;colormap(ax,turbo);colorbar(ax);
        if isfield(R,'qualityKind'),title(ax,'局部方向一致性  蓝低 红高');else,title(ax,'模型受扰动评分  蓝低 红高');end;hold(ax,'off');
    otherwise
        imshow(R.original,'Parent',ax);hold(ax,'on');P=R.points;
        if ismember('x',P.Properties.VariableNames),P.x256=P.x;P.y256=P.y;end
        a=P.accepted & P.crossingNumber==1;b=P.accepted & P.crossingNumber==3;c=~P.accepted;
        plot(ax,P.x256(a),P.y256(a),'o','Color',[0 0.45 0.85],'MarkerSize',7,'LineWidth',1.2);
        plot(ax,P.x256(b),P.y256(b),'^','Color',[0.8 0.15 0.06],'MarkerSize',7,'LineWidth',1.2);
        plot(ax,P.x256(c),P.y256(c),'x','Color',[0.55 0.55 0.55],'MarkerSize',5);
        title(ax,sprintf('端点 %d   分叉 %d   抑制 %d',R.endings,R.bifurcations,R.rejected));hold(ax,'off');
end
set(ax,'FontName','Microsoft YaHei','FontSize',11);
end
