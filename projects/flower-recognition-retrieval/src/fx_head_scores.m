function P=fx_head_scores(net,D)
fc=net.Layers(strcmp({net.Layers.Name},'flower_head'));
P=fx_softmax(double(D)*double(fc.Weights)'+double(fc.Bias)');
end
