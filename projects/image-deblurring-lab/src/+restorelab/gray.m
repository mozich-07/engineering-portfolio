function Y = gray(I)
if size(I,3)==3, Y=rgb2gray(I); else, Y=I; end
end
