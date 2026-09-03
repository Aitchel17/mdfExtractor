function io_savetiff(zstack, save_path, resolution, unit)
%IO_SAVETIFF  A whole stack as a multi-page BigTIFF with ImageJ metadata.
%   The file is opened, filled and closed by io_savetiff_open / io_savetiff_frame,
%   so a caller that never holds the whole stack can write the same file by calling
%   those two directly. This is the whole-stack convenience over them, and it is the
%   only place the 3-D / 4-D distinction lives.
%
% IN   zstack      H x W x Z or H x W x Z x C numeric
%      save_path   1 x 1 char     where the TIFF goes
%      resolution  1 x 3 double   [x y z] step per pixel and per page
%      unit        1 x 3 string   the unit of each, e.g. ["um" "um" "sec"]; "pixel" / "frame" when nothing is known
    is4D = ndims(zstack) == 4;
    n_frame = size(zstack, 3);
    n_channel = is4D * size(zstack, 4) + ~is4D;

    [tiff_handle, tagstruct] = io_savetiff_open(save_path, ...
        [size(zstack, 1), size(zstack, 2)], n_frame, n_channel, resolution, unit);

    for i = 1:n_frame
        for c = 1:n_channel
            if is4D
                frame = zstack(:, :, i, c);
            else
                frame = zstack(:, :, i);
            end
            is_last = ~(i < n_frame || (is4D && c < n_channel));
            io_savetiff_frame(tiff_handle, tagstruct, frame, is_last);
        end
    end

    tiff_handle.close();
    fprintf('Saved zstack with metadata to %s\n', save_path);
end
