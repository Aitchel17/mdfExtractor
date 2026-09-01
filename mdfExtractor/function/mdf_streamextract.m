function info = mdf_streamextract(obj, opt)
    % Extract one recording without ever holding it. Every chunk is read, its
    % drift measured, corrected and written straight out; the frame size is not
    % known until the last frame's drift is in, so the .mdf pass writes UNCROPPED
    % and a second pass over the TIFF cuts it. The other channel reuses the table.
    %
    % obj must already carry a demo() state: refimg, motionvertices, xpad, xshift,
    % groupz, medfilt_size. Nothing here is interactive.
    %
    % Inputs:
    %   obj              - mdf_xymovie after demo()
    %   frame_start      - first frame (default 1)
    %   frame_end        - last frame (default info.fcount)
    %   chunk_frames     - frames held at once, the memory ceiling (default 2000)
    %   drift_channel    - channel the drift is measured on, written first
    %   other_channel    - written after, reusing that table; 0 to skip
    %
    % Output:
    %   info - state2info with savefps set, ready for saveinfo
    arguments
        obj
        opt.frame_start   (1,1) {mustBeNumeric} = 1
        opt.frame_end     (1,1) {mustBeNumeric} = obj.info.fcount
        opt.chunk_frames  (1,1) {mustBeNumeric} = 2000
        opt.drift_channel (1,1) {mustBeNumeric} = 1
        opt.other_channel (1,1) {mustBeNumeric} = 2
    end

    groupz       = obj.state.groupz;
    chunk_frames = floor(opt.chunk_frames / groupz) * groupz;
    n_total      = floor((opt.frame_end - opt.frame_start + 1) / groupz) * groupz;
    frame_last   = opt.frame_start + n_total - 1;
    n_out        = n_total / groupz;
    chunk_starts = opt.frame_start : chunk_frames : frame_last;
    loaded_width = (obj.state.xpadend - obj.state.xpadstart + 1) - abs(obj.state.xshift);

    % medfilt3 reaches floor(z/2) columns either way, and the interpolation reads
    % one column beyond the chunk on both sides, so the read carries one more
    overlap_groups = floor(obj.state.medfilt_size(3) / 2) + 1;
    % the filtered stack is read only inside the motion rectangle, so the filter
    % runs on that box grown by the window's own xy reach. The grown margin is
    % what gives a rectangle edge pixel its true neighbours instead of medfilt3's
    % symmetric padding; z needs none, overlap_groups already carries it
    motion_xy    = round(obj.state.motionvertices);
    reach        = floor(obj.state.medfilt_size(1:2) / 2);   % 1 x 2 count
    medfilt_rows = max(1, motion_xy(1,2) - reach(1)) : min(obj.info.fheight, motion_xy(3,2) + reach(1));   % 1 x n index
    medfilt_cols = max(1, motion_xy(1,1) - reach(2)) : min(loaded_width, motion_xy(3,1) + reach(2));       % 1 x n index
    % pre_applymotion maps the table onto the frames with linspace, and both ends
    % are known before any frame is read, so every frame's position is too
    shift_at = @(frame) 1 + (frame - opt.frame_start) * (n_out - 1) / (n_total - 1);

    obj.state = obj.updatestate('ch2read', opt.drift_channel);
    info = obj.state2info();
    info.savefps = info.fps / groupz;
    if isa(info.objpix, 'double')
        resolution = [info.objpix, info.objpix, 1/info.savefps];
    else
        resolution = [str2double(info.objpix(1:end-2)), str2double(info.objpix(1:end-2)), 1/info.savefps];
    end
    name = info.mdfName(1:end-4);

    %% one pass over the .mdf, written uncropped
    raw_path = fullfile(obj.state.save_folder, sprintf('%s_ch%d_uncropped.tif', name, opt.drift_channel));
    [raw_handle, raw_tags] = io_savetiff_open(raw_path, ...
        [obj.info.fheight, loaded_width], n_out, 1, resolution);

    drift_table = [];
    written = 0;
    for chunk_idx = 1:numel(chunk_starts)
        chunk_start = chunk_starts(chunk_idx);
        chunk_stop  = min(chunk_start + chunk_frames - 1, frame_last);
        read_start  = max(opt.frame_start, chunk_start - overlap_groups*groupz);
        read_stop   = min(frame_last, chunk_stop + overlap_groups*groupz);
        obj.state   = obj.updatestate("loadstart", read_start, "loadend", read_stop);
        stack = obj.loadframes;

        averaged    = pre_groupaverage(stack, groupz);
        medfilt_box = averaged(medfilt_rows, medfilt_cols, :);
        medfilt_box = medfilt3(medfilt_box, obj.state.medfilt_size);
        averaged(medfilt_rows, medfilt_cols, :) = medfilt_box;

        read_col1 = (read_start  - opt.frame_start)/groupz + 1;
        chunk_col = (chunk_start - opt.frame_start)/groupz + 1;
        n_own     = (chunk_stop - chunk_start + 1) / groupz;
        frame_pos = shift_at(chunk_start : chunk_stop);
        col_idx   = max(1, floor(frame_pos(1))) : min(n_out, ceil(frame_pos(end)));

        chunk_drift = pre_estimatemotion(averaged(:, :, col_idx - read_col1 + 1), ...
            obj.state.refimg, obj.state.motionvertices);
        clear averaged
        own_col = (chunk_col : chunk_col + n_own - 1) - col_idx(1) + 1;
        drift_table = [drift_table, chunk_drift(:, own_col)]; %#ok<AGROW>

        shift_row = interp1(col_idx, chunk_drift(3, :), frame_pos, 'linear');
        shift_col = interp1(col_idx, chunk_drift(4, :), frame_pos, 'linear');
        written = write_chunk(raw_handle, raw_tags, stack, ...
            chunk_start - read_start, chunk_stop - chunk_start + 1, ...
            shift_row, shift_col, groupz, written, n_out, ...
            [1, obj.info.fheight], [1, loaded_width]);
        clear stack chunk_drift
        fprintf('%s ch%d: chunk %d of %d, %d of %d written\n', ...
            name, opt.drift_channel, chunk_idx, numel(chunk_starts), written, n_out);
    end
    raw_handle.close();

    mdf_xymovie.savemotion(drift_table, obj.info.fps/groupz, ...
        fullfile(obj.state.save_folder, [name, '_motion.txt']));

    %% second pass, over the TIFF
    [row_range, col_range] = pre_cropbounds(drift_table, [obj.info.fheight, loaded_width]);
    io_croptiff(raw_path, fullfile(obj.state.save_folder, ...
        sprintf('%s_ch%d.tif', name, opt.drift_channel)), row_range, col_range, n_out, resolution);
    delete(raw_path);   % the uncropped pass is only a staging file

    %% the other channel: the table is measured, so it only reads and writes
    %  and the two ranges are already known, so this one is written cut and needs no
    %  second pass -- the uncropped file that forces one on channel 1 is the
    %  price of not knowing the frame size until the last drift is in
    if opt.other_channel > 0
        obj.state = obj.updatestate('ch2read', opt.other_channel);
        cut_path  = fullfile(obj.state.save_folder, ...
            sprintf('%s_ch%d.tif', name, opt.other_channel));
        cut_size = [row_range(2)-row_range(1)+1, col_range(2)-col_range(1)+1];
        [cut_handle, cut_tags] = io_savetiff_open(cut_path, cut_size, n_out, 1, resolution);

        frame_pos = shift_at(opt.frame_start : frame_last);
        shift_row = interp1(1:n_out, drift_table(3, :), frame_pos, 'linear');
        shift_col = interp1(1:n_out, drift_table(4, :), frame_pos, 'linear');

        written = 0;
        for chunk_idx = 1:numel(chunk_starts)
            chunk_start = chunk_starts(chunk_idx);
            chunk_stop  = min(chunk_start + chunk_frames - 1, frame_last);
            obj.state   = obj.updatestate("loadstart", chunk_start, "loadend", chunk_stop);
            stack = obj.loadframes;
            at    = chunk_start - opt.frame_start + 1;
            n_in  = chunk_stop - chunk_start + 1;
            written = write_chunk(cut_handle, cut_tags, stack, 0, n_in, ...
                shift_row(at:at+n_in-1), shift_col(at:at+n_in-1), groupz, ...
                written, n_out, row_range, col_range);
            clear stack
            fprintf('%s ch%d: chunk %d of %d, %d of %d written\n', ...
                name, opt.other_channel, chunk_idx, numel(chunk_starts), written, n_out);
        end
        cut_handle.close();
    end
end

function written = write_chunk(handle, tags, stack, offset, n_in, shift_row, shift_col, ...
        groupz, written, n_out, row_range, col_range)
    % Correct at full rate, average groupz of them, write one. One group at a
    % time, so the corrected full-rate frames never pile up.
    group_buf = zeros(row_range(2)-row_range(1)+1, col_range(2)-col_range(1)+1, groupz, 'like', stack);
    for frame_idx = 1:n_in
        frame = imtranslate(stack(:, :, offset + frame_idx), ...
            [round(shift_col(frame_idx)), round(shift_row(frame_idx))], 'FillValues', -2048);
        group_buf(:, :, mod(frame_idx-1, groupz)+1) = frame(row_range(1):row_range(2), col_range(1):col_range(2));
        if mod(frame_idx, groupz) == 0
            written = written + 1;
            io_savetiff_frame(handle, tags, mean(group_buf, 3), written == n_out);
        end
    end
end

