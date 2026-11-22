function results = run_tests()
c=setup_project(); results=runtests(fullfile(c.root,'tests','test_restoration.m'));
T=table({results.Name}',[results.Passed]',[results.Failed]',[results.Incomplete]',[results.Duration]', ...
    'VariableNames',{'Name','Passed','Failed','Incomplete','Seconds'});
writetable(T,fullfile(c.root,'results','test_results.csv'));
assert(all([results.Passed]),'RestoreLab:TestsFailed','存在失败或未完成的测试，请查看 test_results.csv。');
fprintf('PASS: %d tests.\n',numel(results));
end
