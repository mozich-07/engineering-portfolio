function cartoon_write_json(path,data)
fid=fopen(path,'w','n','UTF-8');
if fid<0,error('Cartoon:Write','无法写入：%s',path);end
cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(data,'PrettyPrint',true));
end
