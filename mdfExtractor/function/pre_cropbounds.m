function [row_range, col_range] = pre_cropbounds(drift_table, frame_size)
% Remove boundary that contains out of boundary
%   One range per axis, so a caller cannot pair them the wrong way round without
%   the line reading wrong. That is not hypothetical -- see the warning below.
% IN   drift_table  4 x N double   dft_registration output. Row 3 = row shift,
%                                  row 4 = column shift
%      frame_size   1 x 2 double   [height width] of the shifted frame
% OUT  row_range    1 x 2 double   [start end], inclusive, 1-based
%      col_range    1 x 2 double   [start end], inclusive, 1-based
%
%   EVERY TIFF EXTRACTED BEFORE 2026-08-29 WAS CUT WITH THE TWO AXES CROSSED --
%   row bounds from the column shifts and column bounds from the row shifts. A
%   re-extract therefore does NOT reproduce the file already on disk, and an ROI
%   drawn on an old extract does not land on the same pixels in a new one.
%   see CLAUDE_LOG.md

    max_row = max(drift_table(3, :));
    min_row = min(drift_table(3, :));
    max_col = max(drift_table(4, :));
    min_col = min(drift_table(4, :));

    row_range = [1 + max(0, max_row), frame_size(1) + min(0, min_row)];
    col_range = [1 + max(0, max_col), frame_size(2) + min(0, min_col)];
end
