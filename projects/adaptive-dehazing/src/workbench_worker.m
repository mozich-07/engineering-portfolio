function workbench_worker(projectRoot,runtimeDir)
%WORKBENCH_WORKER One persistent local MATLAB worker; jobs are serialized.
addpath(fullfile(projectRoot,'01_程序'));
% A local file lock prevents two MATLAB sessions from consuming the same queue.
try
 lock=System.IO.FileStream(fullfile(runtimeDir,'worker.lock'),System.IO.FileMode.OpenOrCreate,System.IO.FileAccess.ReadWrite,System.IO.FileShare.None);
catch
 fprintf('Another workbench worker already owns this queue.\n');return;
end
lockCleanup=onCleanup(@()lock.Dispose()); %#ok<NASGU>
jobsDir=fullfile(runtimeDir,'jobs');if ~isfolder(jobsDir),mkdir(jobsDir);end
writeState('ready','MATLAB 已就绪');
lastActivity=tic;
while ~isfile(fullfile(runtimeDir,'stop.flag')) && toc(lastActivity)<7200
 jobs=dir(jobsDir);jobs=jobs([jobs.isdir]);names=sort({jobs.name});worked=false;
 for k=1:numel(names)
  name=names{k};if startsWith(name,'.'),continue;end
  job=fullfile(jobsDir,name);request=fullfile(job,'request.json');
  if ~isfile(request)||isfile(fullfile(job,'done.flag')),continue;end
  if isfile(fullfile(runtimeDir,'stop.flag')),break;end
  worked=true;lastActivity=tic;
  if isfile(fullfile(job,'cancel.flag'))
   saveStatus(job,'cancelled','已取消，未执行处理');finish(job);continue;
  end
  try
   req=jsondecode(fileread(request));
   inp=fullfile(job,req.inputName); % only generated local basename, never user path
   if ~isempty(regexp(req.inputName,'[\\/]|\.\.','once')),error('Workbench:Path','非法输入文件名');end
   ref='';
   if isfield(req,'referenceName') && ~isempty(req.referenceName)
    if ~isempty(regexp(req.referenceName,'[\\/]|\.\.','once')),error('Workbench:Path','非法参考文件名');end
    ref=fullfile(job,req.referenceName);
   end
   workbench_case(inp,job,req.options,ref,req.meta);
   if isfile(fullfile(job,'cancel.flag')),saveStatus(job,'cancelled','计算已结束；按请求取消，不展示结果');end
  catch e
   saveStatus(job,'error',[e.identifier ': ' e.message]);
  end
  finish(job);
 end
 if ~worked,pause(.4);end
end
writeState('stopped','MATLAB 工作进程已退出');
 function writeState(state,message)
  writeJSON(fullfile(runtimeDir,'worker.json'),struct('state',state,'message',message,'pid',feature('getpid')));
 end
end
function finish(job)
fid=fopen(fullfile(job,'done.flag'),'w');fclose(fid);
end
function saveStatus(job,state,message)
writeJSON(fullfile(job,'status.json'),struct('state',state,'message',message,'progress',0));
end
function writeJSON(path,v)
fid=fopen([path '.tmp'],'w','n','UTF-8');fprintf(fid,'%s',jsonencode(v));fclose(fid);movefile([path '.tmp'],path,'f');
end
