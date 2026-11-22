function out = run_demo()
c=setup_project(); model=restorelab.load_model(c);
I=restorelab.read_image(fullfile(c.root,'data','external','chelsea.png'),512);
p=c.cases(2); B=restorelab.degrade(I,p,0.015,c.seed+900000);
out=restorelab.process(B,p,0.015,model,[],I);
restorelab.export_result(out,fullfile(c.root,'results','demo'),I);
disp(out.metrics); fprintf('Demo exported to results/demo.\n');
end
