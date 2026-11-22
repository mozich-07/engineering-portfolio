function check_environment()
required={'uifigure','imageDatastore','imresize','fitcecoc','templateLinear','assembleNetwork','trainNetwork','activations'};
missing=required(cellfun(@(f)isempty(which(f)),required));
assert(isempty(missing),'缺少必要工具箱函数：%s',strjoin(missing,', '));
fprintf('MATLAB %s。需要图像处理、统计与机器学习、深度学习工具箱。\n',version);
root=fileparts(mfilename('fullpath'));
assert(isfile(fullfile(root,'models','active_run.txt')),'模型文件不完整，请完整解压最终版文件夹。');
assert(isfolder(fullfile(root,'data','oxford102','jpg')),'未找到图片数据，请完整解压，不要只复制启动文件。');
fprintf('环境检查通过。正常识别无需联网或重新训练。\n');
end
