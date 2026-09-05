function info = io_loadinfo(info_path)
%IO_LOADINFO  The _info.txt saveinfo wrote, back as a struct: one field per row, values as written.
%   Caller: mdfExtractLoader constructor, mdf_xymovie.restore
%
% IN   info_path  1 x n char     the _info.txt
% OUT  info       1 x 1 struct   Field -> Value, every value the char it was written as
    saved = readtable(info_path);
    info = struct();
    for k = 1:height(saved)
        info.(saved.Field{k}) = saved.Value{k};
    end
end
