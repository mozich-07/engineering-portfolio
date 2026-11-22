function input=fx_input(I)
% Use the same public datastore resizing path as feature extraction.
% imresize's default bicubic interpolation differs from this datastore.
c=fx_config();ds=augmentedImageDatastore(c.inputSize,im2uint8(I));
batch=read(ds);input=batch.input{1};
end
