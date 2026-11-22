function run_all()
% RUN_ALL Reproduce data, training, validation, test and demonstration.
c=setup_project();
diary(fullfile(c.root,'results','run_all.log')); clean=onCleanup(@()diary('off'));
fprintf('RestoreLab run started: %s\n',char(datetime('now')));
prepare_data(); train_project(); evaluate_project(); run_demo(); run_tests();
fprintf('Completed: %s\n',char(datetime('now')));
end
