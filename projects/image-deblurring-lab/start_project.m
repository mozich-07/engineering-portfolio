function app = start_project(visibility)
% START_PROJECT Launch the Chinese MATLAB desktop application.
if nargin<1, visibility='on'; end
setup_project(); app=RestoreLabApp(visibility);
end
