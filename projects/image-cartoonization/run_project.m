function fig = run_project(varargin)
%RUN_PROJECT 启动数字图像处理课程项目。默认离线，无摄像头或训练依赖。
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root,'src'));
cartoon_check_environment();
fig = cartoon_app(root,varargin{:});
end
