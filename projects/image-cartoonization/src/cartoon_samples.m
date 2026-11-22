function items = cartoon_samples(root)
items=jsondecode(fileread(fullfile(root,'samples','manifest.json')));
end
