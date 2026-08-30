% Streaming variant of example_mdfxymovie. The whole recording is never held.
%
% One pass over the .mdf: every chunk is read, its drift measured, corrected and
% written straight out. The frame size is not known until the last frame's drift
% is in, so the .mdf pass writes UNCROPPED and a second pass over the TIFF -- one
% tenth the frames, on local disk -- cuts it to the common valid region.
%
% Chunks are whole multiples of groupz, and the total is truncated to a multiple,
% so the group boundaries are the ones pre_groupaverage would have picked over the
% whole stack. Chunks overlap so medfilt3 sees the neighbours it would have seen
% there, and so the interpolation has the column after the chunk's own last one.

file1 = mdf_xymovie();
file1 = file1.loadbehavior();

%% state for image correction: reference channel, motion vertices, xshift, xpad
file1.state = file1.demo(1, groupz=10);

%%
param.frame_start   = 1;
param.frame_end     = file1.info.fcount;
param.chunk_frames  = 2000;   % frames held at once, the memory ceiling (count)
param.drift_channel = 1;      % channel the drift is measured on, written first
param.other_channel = 2;      % written after, reusing that drift table

groupz       = file1.state.groupz;
chunk_frames = floor(param.chunk_frames / groupz) * groupz;
n_total      = floor((param.frame_end - param.frame_start + 1) / groupz) * groupz;
frame_last   = param.frame_start + n_total - 1;
n_out        = n_total / groupz;
chunk_starts = param.frame_start : chunk_frames : frame_last;

% medfilt3 reaches floor(z/2) columns either way, and the interpolation reads one
% column beyond the chunk on both sides, so the read carries one more than that.
% The extra column is on BOTH sides: linspace maps the table with a step of
% (n_out-1)/(n_total-1), a hair under 1/groupz, so a chunk's first frame lands
% just before that chunk's own first column
overlap_groups = floor(file1.state.medfilt_size(3) / 2) + 1;

% pre_applymotion maps the table onto the frames with linspace, and both its ends
% are known before any frame is read, so the position of every frame is too
shift_at = @(frame) 1 + (frame - param.frame_start) * (n_out - 1) / (n_total - 1);

%% One pass over the .mdf, written uncropped
file1.state = file1.updatestate('ch2read', param.drift_channel);
loaded_width = (file1.state.xpadend - file1.state.xpadstart + 1) - abs(file1.state.xshift);

info = file1.state2info();
info.savefps = info.fps / groupz;
if isa(info.objpix, 'double')
    resolution = [info.objpix, info.objpix, 1/info.savefps];
else
    resolution = [str2double(info.objpix(1:end-2)), str2double(info.objpix(1:end-2)), 1/info.savefps];
end
raw_path  = fullfile(file1.state.save_folder, ...
    [info.mdfName(1:end-4), sprintf('_ch%d_uncropped.tif', param.drift_channel)]);
save_path = fullfile(file1.state.save_folder, ...
    [info.mdfName(1:end-4), sprintf('_ch%d.tif', param.drift_channel)]);

[raw_handle, raw_tags] = io_savetiff_open(raw_path, ...
    [file1.info.fheight, loaded_width], n_out, 1, resolution);
raw_closer = onCleanup(@() raw_handle.close());

drift_table = [];
written = 0;
for chunk_idx = 1:numel(chunk_starts)
    chunk_start = chunk_starts(chunk_idx);
    chunk_stop  = min(chunk_start + chunk_frames - 1, frame_last);
    read_start  = max(param.frame_start, chunk_start - overlap_groups*groupz);
    read_stop   = min(frame_last, chunk_stop + overlap_groups*groupz);
    file1.state = file1.updatestate("loadstart", read_start, "loadend", read_stop);
    stack = file1.loadframes;

    averaged = pre_groupaverage(stack, groupz);
    averaged = medfilt3(averaged, file1.state.medfilt_size);

    % keep exactly the columns the interpolation reaches for this chunk
    read_col1 = (read_start   - param.frame_start)/groupz + 1;
    chunk_col = (chunk_start  - param.frame_start)/groupz + 1;
    n_own     = (chunk_stop - chunk_start + 1) / groupz;
    frame_pos = shift_at(chunk_start : chunk_stop);
    col_idx   = max(1, floor(frame_pos(1))) : min(n_out, ceil(frame_pos(end)));

    chunk_drift = pre_estimatemotion(averaged(:, :, col_idx - read_col1 + 1), ...
        file1.state.refimg, file1.state.motionvertices);
    clear averaged
    own_col = (chunk_col : chunk_col + n_own - 1) - col_idx(1) + 1;
    drift_table = [drift_table, chunk_drift(:, own_col)]; %#ok<AGROW>

    shift_row = interp1(col_idx, chunk_drift(3, :), frame_pos, 'linear');
    shift_col = interp1(col_idx, chunk_drift(4, :), frame_pos, 'linear');

    % one group at a time, so the corrected full-rate frames never pile up
    group_buf = zeros(file1.info.fheight, loaded_width, groupz, 'like', stack);
    for frame_idx = 1:(chunk_stop - chunk_start + 1)
        group_buf(:, :, mod(frame_idx-1, groupz)+1) = imtranslate( ...
            stack(:, :, (chunk_start - read_start) + frame_idx), ...
            [round(shift_col(frame_idx)), round(shift_row(frame_idx))], 'FillValues', -2048);
        if mod(frame_idx, groupz) == 0
            written = written + 1;
            io_savetiff_frame(raw_handle, raw_tags, mean(group_buf, 3), written == n_out);
        end
    end
    clear stack group_buf chunk_drift
    fprintf('chunk %d of %d: frames %d-%d, %d of %d written\n', ...
        chunk_idx, numel(chunk_starts), chunk_start, chunk_stop, written, n_out);
end
clear raw_closer   % closes the uncropped TIFF

figure('name', 'Pixel Shift', 'NumberTitle', 'off');
subplot(2, 1, 1);
plot(drift_table(4, :));
title('X shift');
subplot(2, 1, 2);
plot(drift_table(3, :));
title('Y shift');

driftfile = fullfile(file1.state.save_folder, [file1.info.mdfName(1:end-4), '_motion.txt']);
mdf_xymovie.savemotion(drift_table, file1.info.fps/groupz, driftfile);
file1.drifttable = drift_table;

%% Second pass, over the TIFF: cut to the region every frame filled
crop_bounds = zeros(1, 4);
[crop_bounds(1), crop_bounds(2), crop_bounds(3), crop_bounds(4)] = ...
    pre_cropbounds(drift_table, [file1.info.fheight, loaded_width]);
crop_tiff(raw_path, save_path, crop_bounds, n_out, resolution);
fprintf('cropped to rows %d:%d, cols %d:%d\n', crop_bounds);

%% The other channel: the drift table is measured, so it only reads and writes
% No overlap is needed here -- nothing is filtered and no shift is estimated, so
% a chunk needs nothing from its neighbours.
file1.state = file1.updatestate('ch2read', param.other_channel);
raw_path  = fullfile(file1.state.save_folder, ...
    [info.mdfName(1:end-4), sprintf('_ch%d_uncropped.tif', param.other_channel)]);
save_path = fullfile(file1.state.save_folder, ...
    [info.mdfName(1:end-4), sprintf('_ch%d.tif', param.other_channel)]);

[raw_handle, raw_tags] = io_savetiff_open(raw_path, ...
    [file1.info.fheight, loaded_width], n_out, 1, resolution);
raw_closer = onCleanup(@() raw_handle.close());

frame_pos = shift_at(param.frame_start : frame_last);
shift_row = interp1(1:n_out, drift_table(3, :), frame_pos, 'linear');
shift_col = interp1(1:n_out, drift_table(4, :), frame_pos, 'linear');

written = 0;
for chunk_idx = 1:numel(chunk_starts)
    chunk_start = chunk_starts(chunk_idx);
    chunk_stop  = min(chunk_start + chunk_frames - 1, frame_last);
    file1.state = file1.updatestate("loadstart", chunk_start, "loadend", chunk_stop);
    stack = file1.loadframes;

    group_buf = zeros(file1.info.fheight, loaded_width, groupz, 'like', stack);
    for frame_idx = 1:(chunk_stop - chunk_start + 1)
        at = chunk_start - param.frame_start + frame_idx;
        group_buf(:, :, mod(frame_idx-1, groupz)+1) = imtranslate(stack(:, :, frame_idx), ...
            [round(shift_col(at)), round(shift_row(at))], 'FillValues', -2048);
        if mod(frame_idx, groupz) == 0
            written = written + 1;
            io_savetiff_frame(raw_handle, raw_tags, mean(group_buf, 3), written == n_out);
        end
    end
    clear stack group_buf
    fprintf('ch%d chunk %d of %d, %d of %d written\n', ...
        param.other_channel, chunk_idx, numel(chunk_starts), written, n_out);
end
clear raw_closer
crop_tiff(raw_path, save_path, crop_bounds, n_out, resolution);

%%
file1.info = info;
file1.saveinfo;
file1.savebehavior();

%% ------------------------------------------------------------------
function crop_tiff(raw_path, save_path, bounds, n_out, resolution)
    % Read the uncropped TIFF a frame at a time, write the cut one, drop the first
    [out_handle, out_tags] = io_savetiff_open(save_path, ...
        [bounds(2)-bounds(1)+1, bounds(4)-bounds(3)+1], n_out, 1, resolution);
    out_closer = onCleanup(@() out_handle.close());
    raw_reader = Tiff(raw_path, 'r');
    reader_closer = onCleanup(@() raw_reader.close());
    for out_idx = 1:n_out
        raw_reader.setDirectory(out_idx);
        frame = raw_reader.read();
        io_savetiff_frame(out_handle, out_tags, ...
            frame(bounds(1):bounds(2), bounds(3):bounds(4)), out_idx == n_out);
    end
    clear out_closer reader_closer
    delete(raw_path);
end
