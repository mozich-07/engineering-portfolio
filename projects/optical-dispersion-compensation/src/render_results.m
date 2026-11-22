function render_results(r,out)
% RENDER_RESULTS All plotted values come from saved experiment outputs.
set(groot,'defaultAxesFontName','Microsoft YaHei','defaultTextFontName','Microsoft YaHei');
f=figure('Visible','off','Color','w','Position',[100 100 1200 700]);
tiledlayout(2,2,'Padding','compact'); e=r.example;
zs={e.tx,e.rx,e.ml,e.oracle}; titles={'发送星座','色散后 未补偿','岭回归学习均衡','已知参数 理想补偿'};
for j=1:4
    nexttile; plot(real(zs{j}),imag(zs{j}),'.','MarkerSize',4); axis equal; xlim([-2 2]); ylim([-2 2]); grid on;
    title(titles{j}); xlabel('同相分量 I'); ylabel('正交分量 Q');
end
sgtitle(sprintf('%g km / Es/N0 = %g dB / 独立测试块',e.lengthKm,e.snrDb));
exportgraphics(f,fullfile(out,'constellations.png'),'Resolution',160); close(f);
f=figure('Visible','off','Color','w','Position',[100 100 1050 600]);
names={'Uncompensated','Fixed60km','RidgeML','OracleCD'};
labels={'未补偿','固定60 km补偿','岭回归均衡','真实参数补偿'};
hold on;
for j=1:4
    q=r.summary(strcmp(r.summary.Method,names{j}),:);
    semilogy(q.SNRdB,max(q.BER,0.5./q.TotalBits),'-o','LineWidth',1.8,'DisplayName',labels{j});
end
set(gca,'YScale','log'); grid on; xlabel('Es/N0 (dB)'); ylabel('误码率 BER');
title('80 km 独立测试 每个信噪比196608 bit'); legend('Location','southwest');
subtitle('零误码点显示于 0.5/N，仅作对数绘图占位，详见原始计数');
exportgraphics(f,fullfile(out,'ber_sweep.png'),'Resolution',160); close(f);
f=figure('Visible','off','Color','w','Position',[100 100 1050 600]);
semilogx(r.curve.TrainSamples,r.curve.TrainNMSE,'-o',r.curve.TrainSamples,r.curve.ValidationNMSE,'-s','LineWidth',1.8);
grid on; xlabel('训练样本数'); ylabel('归一化均方误差 NMSE'); legend('训练集','验证集');
title('样本量学习曲线 闭式求解无迭代轮次');
exportgraphics(f,fullfile(out,'learning_curve.png'),'Resolution',160); close(f);
f=figure('Visible','off','Color','w','Position',[100 100 1050 600]);
K=r.config.windows; vals=zeros(size(K));
for j=1:numel(K), vals(j)=min(r.search.ValidationNMSE(r.search.Window==K(j))); end
semilogy(K,vals,'-o','LineWidth',1.8); grid on; xlabel('接收窗口长度 K'); ylabel('验证集最优 NMSE');
title('窗口消融 单符号不能恢复色散造成的记忆');
exportgraphics(f,fullfile(out,'window_ablation.png'),'Resolution',160); close(f);
end
