function model = load_model(c)
if ~isfile(c.modelPath)
    error('RestoreLab:MissingModel','缺少模型。请先运行 train_project 或 run_all。');
end
S=load(c.modelPath,'model'); model=S.model;
assert(isfield(model,'version') && strcmp(model.version,'ridge-residual-v1'), ...
    'RestoreLab:ModelVersion','模型版本不匹配，请重新训练。');
assert(numel(model.beta)==52 && all(isfinite(model.beta)), ...
    'RestoreLab:ModelFormat','模型参数不完整。');
end
