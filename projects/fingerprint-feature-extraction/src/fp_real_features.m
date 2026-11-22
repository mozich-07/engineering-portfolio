function [x,names]=fp_real_features(I)
if size(I,3)==3,I=rgb2gray(I);end
I=imresize(im2double(I),[256 256]);[f,~,base]=fp_features(I);
x=[mean(f,1),std(f,0,1),prctile(f,25,1),prctile(f,75,1)];
names=[strcat('mean_',base),strcat('std_',base),strcat('q25_',base),strcat('q75_',base)];
end
