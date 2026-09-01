function io_croptiff(raw_path, save_path, row_range, col_range, n_out, resolution)
%IO_CROPTIFF  Read a TIFF a frame at a time and write the cut one beside it.
%   Neither file is held whole. The source is LEFT ALONE -- a caller that wants
%   it gone deletes it itself, where the deletion is visible.
%
% IN   raw_path    1 x n char     the uncropped TIFF
%      save_path   1 x n char     where the cut one goes
%      row_range   1 x 2 double   [start end] from pre_cropbounds, inclusive
%      col_range   1 x 2 double   [start end], inclusive
%      n_out       1 x 1 double   frames in the source
%      resolution  1 x 3 double   [x_res y_res z_res], microns and seconds
    frame_size = [row_range(2)-row_range(1)+1, col_range(2)-col_range(1)+1];
    [out_handle, out_tags] = io_savetiff_open(save_path, frame_size, n_out, 1, resolution);
    raw_reader = Tiff(raw_path, 'r');
    for out_idx = 1:n_out
        raw_reader.setDirectory(out_idx);
        frame = raw_reader.read();
        cut   = frame(row_range(1):row_range(2), col_range(1):col_range(2));
        io_savetiff_frame(out_handle, out_tags, cut, out_idx == n_out);
    end
    out_handle.close();
    raw_reader.close();
end
