function imgnew = image_bin(img,bin,scale)
imgnew = zeros(size(img)/bin);
for j=1:bin
    for k=1:bin
        imgnew = imgnew + img(j:bin:end,k:bin:end);
    end
end
if nargin>2 && scale, imgnew = imgnew/bin^2; end