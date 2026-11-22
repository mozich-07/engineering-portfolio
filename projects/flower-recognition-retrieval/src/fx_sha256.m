function h=fx_sha256(path)
fid=fopen(path,'rb'); if fid<0, error('Flower:File','无法读取文件'); end
cleanup=onCleanup(@()fclose(fid)); bytes=fread(fid,inf,'*uint8');
md=java.security.MessageDigest.getInstance('SHA-256'); md.update(bytes);
digest=typecast(md.digest(),'uint8'); h=string(lower(reshape(dec2hex(digest,2)',1,[])));
end
