function [model,folder]=fx_load()
c=fx_config();pointer=fullfile(c.models,'active_run.txt');assert(isfile(pointer),'请先运行 train_project 完成训练。');
id=strtrim(fileread(pointer));assert(~isempty(regexp(id,'^\d{8}_\d{6}$','once')),'模型指针格式无效');
folder=fullfile(c.experiments,id);s=load(fullfile(folder,'model.mat'),'model');model=s.model;
end
