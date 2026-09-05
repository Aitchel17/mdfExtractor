function io_1d2txt(save_path, info_title, info, data_title, data)
%IO_1D2TXT  Two structs as a text file: a title line, then one "name: value" per field.
%   Caller: mdf_peripheral.saveanalog, mdf_xymovie.savemotion
%
% IN   save_path   1 x n char     where the text goes
%      info_title  1 x n char     the first section's title, written as given
%      info        1 x 1 struct   one line per field; scalars and short strings
%      data_title  1 x n char     the second section's title, written as given
%      data        1 x 1 struct   one line per field; 1 x N rows, as mat2str writes them
%
%   A char field goes as written and anything else through mat2str. Titles are verbatim, which
%   is the blank line _analog.txt has before its data title and _motion.txt has not.
    fid = fopen(save_path, 'w');
    closer = onCleanup(@() fclose(fid));   % closes on the way out, error or not
    write_section(fid, info_title, info);
    write_section(fid, data_title, data);
end

function write_section(fid, title, section)
    fprintf(fid, '%s\n', title);
    name_list = fieldnames(section);
    for k = 1:numel(name_list)
        value = section.(name_list{k});
        if ischar(value)
            text = value;
        else
            text = mat2str(value);
        end
        fprintf(fid, '%s: %s\n', name_list{k}, text);
    end
end
