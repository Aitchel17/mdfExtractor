function [zstack,interp_drifttable] = pre_applymotion(zstack, drift_table)
    % Apply motion correction using drift table and preserve common area
    fprintf('Apply drift correction\n');

    % Validate inputs
    num_frames = size(zstack,3);

    % Extract and interpolate shifts
    original_frames = 1:size(drift_table, 2);
    interp_frames = linspace(1, size(drift_table, 2), num_frames);
    row_shifts_interp = interp1(original_frames, drift_table(3, :), interp_frames, 'linear');
    col_shifts_interp = interp1(original_frames, drift_table(4, :), interp_frames, 'linear');
    max_row = max(drift_table(3, :));
    min_row = min(drift_table(3, :));
    max_col = max(drift_table(4, :));
    min_col = min(drift_table(4, :));
    % Process frames in place
    tic;
    for i = 1:num_frames
        if mod(i, 1000) == 0 || i == 1
            fprintf('Processing frame %d/%d\n', i, num_frames);
        end

        % Extract the current frame
        frame = zstack(:, :, i);

        % Compute integer shifts
        row_shift = round(row_shifts_interp(i));
        col_shift = round(col_shifts_interp(i));

        % Shift the frame using 'OutputView' set to 'full' to capture padding
         zstack(:, :, i) = imtranslate(frame, [col_shift, row_shift], 'FillValues', -2048);
    end
    toc;
    % Crop to the common valid region across all shifted frames.
    % max(0,...) ensures we never add a positive offset to the start index
    % min(0,...) ensures we never add a positive offset to the end index
    row_start = 1  + max(0, max_col);
    row_end   = size(zstack, 1) + min(0, min_col);
    col_start = 1  + max(0, max_row);
    col_end   = size(zstack, 2) + min(0, min_row);
    zstack = zstack(row_start:row_end, col_start:col_end, :);

    fprintf('Pixel shift correction completed.\n');

    % Return interpolated drift table
    interp_drifttable = [row_shifts_interp; col_shifts_interp];
end
