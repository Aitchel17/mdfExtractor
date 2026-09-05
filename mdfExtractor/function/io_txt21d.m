function [info, data] = io_txt21d(load_path)
%IO_TXT21D  The two structs io_1d2txt wrote, back: a title line, then one "name: value" per field.
%   Caller: mdfExtractLoader.loadanalog_info, mdfExtractLoader.loadanalog_data, mdfExtractLoader.loadmotion
%
% IN   load_path  1 x n char     the text
% OUT  info       1 x 1 struct   the first section, each value the char it was written as
%      data       1 x 1 struct   the second section, each value as str2num reads it (1 x N)
%
%   A title is a line starting with ---; the first opens info, the second opens data.
%   Blank lines are skipped, so the one _analog.txt has before its data title is too.
    lines = readlines(load_path);
    info = struct();
    data = struct();
    section = 0;
    for k = 1:numel(lines)
        line = strtrim(lines(k));
        if startsWith(line, "---")
            section = section + 1;
            continue
        end
        if line == ""
            continue
        end
        name_value = regexp(line, "^([^:]+):\s?(.*)$", 'tokens', 'once');
        name  = char(strtrim(name_value(1)));
        value = char(name_value(2));
        if section == 1
            info.(name) = value;
        else
            data.(name) = str2num(value); %#ok<ST2NM> mat2str wrote it
        end
    end
end
