classdef mdf_xymovie < mdf
    %MDF_XYMOVIE  An XY Movie, drift corrected on the way to disk

    properties
        drifttable = zeros(4, 0)    % 4 x n_page     dft_registration rows, one column per page
    end

    methods
        function obj = mdf_xymovie(paths)
            arguments
                paths = [];
            end
            obj@mdf(paths);   % initialize by parent
            obj = obj.init();
            % default option
            obj.state.groupz = 10;
            obj.state.xpadstart = 1;
            obj.state.xpadend = obj.info.fwidth;
            obj.state.xshift = 0;
            % default motion parameters
            obj.state.motion_medfilt = [3, 3, 5];   % 1 x 3, medfilt3 window [xy xy z]
            obj.state.motion_clahe = false;
            obj.state.motion_clahe_size = 64;      % CLAHE tile side (px)
            obj.state.motion_wiener = false;       % wiener2 and the low-pass after it
        end

        function info = state2info(obj)
            %STATE2INFO  the parent's window and page rate, then what demoload and demomotion settled
            info = state2info@mdf(obj);
            info.xshift            = obj.state.xshift;
            info.motion_refframes  = strjoin(string(obj.state.motion_refframes));   % first and last frame
            info.motion_refchannel = obj.state.motion_refchannel;
            info.motion_vertices   = strjoin(string(reshape(obj.state.motion_vertices', 1, [])));   % by rows
            info.motion_medfilt    = strjoin(string(obj.state.motion_medfilt));   % writetable wants a scalar
            info.motion_clahe      = obj.state.motion_clahe;
            info.motion_clahe_size = obj.state.motion_clahe_size;
            info.motion_wiener     = obj.state.motion_wiener;
        end

        function obj = info2state(obj, saved)
            %INFO2STATE  state2info's inverse: the demo and motion fields typed back out of a loaded info
            %   Caller: mdf_xymovie.restore
            %
            % IN   saved  1 x 1 struct   from io_loadinfo, every value the char it was written as
            % OUT  obj                   state gains groupz, motion_refchannel (ch2read with it),
            %                            motion_refframes, xshift, motion_medfilt, motion_clahe,
            %                            motion_clahe_size, motion_wiener, motion_vertices.
            %                            loadstart / loadend stay: the window is the script's to set
            obj.state.groupz            = str2double(saved.groupz);
            obj.state.motion_refchannel = str2double(saved.motion_refchannel);
            obj.state.ch2read           = obj.state.motion_refchannel;
            obj.state.motion_refframes  = str2num(saved.motion_refframes); %#ok<ST2NM> 1 x 2
            obj.state.xshift            = str2double(saved.xshift);
            % the four below entered state after most of the tree was extracted; the
            % default is what that extraction ran with
            obj.state.motion_medfilt    = str2num(infofield(saved, 'motion_medfilt', '3 3 5')); %#ok<ST2NM> 1 x 3
            obj.state.motion_clahe      = logical(str2double(infofield(saved, 'motion_clahe', '0')));
            obj.state.motion_clahe_size = str2double(infofield(saved, 'motion_clahe_size', '64'));
            obj.state.motion_wiener     = logical(str2double(infofield(saved, 'motion_wiener', '0')));
            % state2info flattens the 4 x 2 by rows, so the inverse is 2 x 4 turned
            flat = str2num(saved.motion_vertices); %#ok<ST2NM> 1 x 8
            obj.state.motion_vertices = reshape(flat, 2, 4)';
        end

        function [obj, demo] = demoload(obj, refimgchannel, option)
            %DEMOLOAD  load demoframes(loadstart, groupz) then determine pshift
            %
            % OUT  obj          state gains motion_refchannel, groupz, xshift
            %      demo.raw     H x W x T int16   as read, margins still at -2048
            %      demo.frames  1 x T double      the acquisition frame of each
            arguments
                obj
                refimgchannel (1,1) {mustBeNumeric}
                option.groupz (1,1) {mustBeNumeric} = obj.state.groupz
            end

            obj.state.motion_refchannel = refimgchannel;
            obj.state.ch2read = refimgchannel;
            obj.state.groupz  = option.groupz;
            demo.frames = obj.demoframes(obj.state.loadstart, obj.state.groupz);
            mobj = obj.openmdf();
            demo.raw = mdf_readframes(mobj, obj.state.motion_refchannel, demo.frames);
            delete(mobj);   % the dialog below only needs the stack, not the file
            obj.state.xshift = mdf_pshiftexplorer(demo.raw);
        end

        function [obj, demo] = demomotion(obj, demo, option)
            %DEMOMOTION  demoprepare - draw box - estimate - apply - check, until accepted
            arguments
                obj
                demo
                option.motion_medfilt (1,3) {mustBeNumeric} = obj.state.motion_medfilt
                option.motion_clahe (1,1) logical = obj.state.motion_clahe
                option.motion_clahe_size (1,1) {mustBeNumeric} = obj.state.motion_clahe_size
                option.motion_wiener (1,1) logical = obj.state.motion_wiener
            end
            obj.state.motion_medfilt    = option.motion_medfilt;
            obj.state.motion_clahe      = option.motion_clahe;
            obj.state.motion_clahe_size = option.motion_clahe_size;
            obj.state.motion_wiener     = option.motion_wiener;

            [demo.processed, obj.state.xpadstart, obj.state.xpadend] = obj.demoprepare(demo.raw);

            % the slice picked is written down as acquisition frames, not as an index
            % into a stack that only exists inside this call
            qualitycontrol = false;
            while qualitycontrol == false
                [obj.state.motion_vertices, ref_slice] = mdf_rectangle_polygon(demo.processed, 'rectangle');
                block = (ref_slice - 1) * obj.state.groupz + 1 : ref_slice * obj.state.groupz;
                obj.state.motion_refframes = [demo.frames(block(1)), demo.frames(block(end))];   % 1 x 2 frame
                obj.state.motion_refimg = demo.processed(:,:,ref_slice);
                demo.drift_table = pre_estimatemotion(demo.processed, obj.state.motion_refimg, obj.state.motion_vertices);
                demo.correctedstack = pre_applymotion(demo.processed, demo.drift_table);
                qualitycontrol = mdf.checkstack(demo.correctedstack);
            end
        end

        function drifttable = getdrifttable(obj)
            %GETDRIFTTABLE  group average - motionpreprocess - estimate, into this read's columns
            %
            % OUT  drifttable  4 x n double   obj.drifttable with the columns this read reaches
            %                                 written in; an edge column is measured again by
            %                                 the neighbouring read, to the same value
            [own_start, own_stop, read_start, ~] = obj.readwindow();
            [~, col_idx] = obj.tablecolumns(own_start, own_stop);
            averaged = pre_groupaverage(obj.stack, obj.state.groupz);
            averaged = mdf_motionpreprocess(averaged, obj.state.motion_medfilt, ...
                obj.state.motion_clahe, obj.state.motion_clahe_size, obj.state.motion_wiener);
            read_col1 = (read_start - obj.state.loadstart) / obj.state.groupz + 1;
            read_drift = pre_estimatemotion(averaged(:, :, col_idx - read_col1 + 1), ...
                obj.state.motion_refimg, obj.state.motion_vertices);
            drifttable = obj.drifttable;
            drifttable(:, col_idx) = read_drift;
        end

        function stack = correctdrift(obj)
            %CORRECTDRIFT  the table interpolated onto this read's own frames, each translated
            %
            % OUT  stack  H x W x n   the own frames only, full rate, same class; -2048 where
            %                         the shift moved nothing in
            [own_start, own_stop, read_start, ~] = obj.readwindow();
            [frame_pos, col_idx] = obj.tablecolumns(own_start, own_stop);
            shift_row = interp1(col_idx, obj.drifttable(3, col_idx), frame_pos, 'linear');
            shift_col = interp1(col_idx, obj.drifttable(4, col_idx), frame_pos, 'linear');
            offset = own_start - read_start;
            n_own  = own_stop - own_start + 1;
            stack  = zeros(size(obj.stack, 1), size(obj.stack, 2), n_own, 'like', obj.stack);
            for k = 1:n_own
                stack(:, :, k) = imtranslate(obj.stack(:, :, offset + k), ...
                    [round(shift_col(k)), round(shift_row(k))], 'FillValues', -2048);
            end
        end

        function stack = afterprocess(obj)
            %AFTERPROCESS  groupz frames into one page
            stack = pre_groupaverage(obj.stack, obj.state.groupz);
        end
        

        function savemotion(obj)
            %SAVEMOTION  write dft_registration's four rows in its order
            % were labelled yerror / xerror / ymotion / xmotion; see CLAUDE_LOG.md
            info.driftestimation_fps = num2str(obj.info.fps / obj.state.groupz);   % char, as written
            motion_rows.regerror  = obj.drifttable(1,:);   % sqrt(1-|CCmax|^2/(E1*E2)), 0 = identical
            motion_rows.diffphase = obj.drifttable(2,:);   % angle(CCmax), 0 for real images
            motion_rows.rowshift  = obj.drifttable(3,:);   % the correction, not the tissue's motion
            motion_rows.colshift  = obj.drifttable(4,:);
            motion_path = fullfile(obj.state.save_folder, [obj.info.mdfName(1:end-4), '_motion.txt']);
            io_1d2txt(motion_path, '--- Motion info ---', info, '--- Motion table ---', motion_rows);
        end
        function obj = restore(obj)
            %RESTORE  The demoload/demomotion state back from the _info.txt, and the reference image with it
            info_path = fullfile(obj.state.save_folder, [obj.info.mdfName(1:end-4), '_info.txt']);
            saved     = io_loadinfo(info_path);
            obj       = obj.info2state(saved);

            frames = obj.demoframes(1, obj.state.groupz);
            at     = find(frames == obj.state.motion_refframes(1), 1);
            if isempty(at) || mod(at - 1, obj.state.groupz) ~= 0 || ...
                    frames(at + obj.state.groupz - 1) ~= obj.state.motion_refframes(2)
                error('mdf_xymovie:restore', ...
                    'frame %d does not start a group of %d in the rebuilt demo list, so the reference cannot be located', ...
                    obj.state.motion_refframes(1), obj.state.groupz);
            end
            ref_slice = (at - 1) / obj.state.groupz + 1;

            mobj = obj.openmdf();
            demo_stack = mdf_readframes(mobj, obj.state.motion_refchannel, frames);
            delete(mobj);
            [demo_stack, obj.state.xpadstart, obj.state.xpadend] = obj.demoprepare(demo_stack);
            obj.state.motion_refimg = demo_stack(:, :, ref_slice);
            fprintf('restored from %s : xpad %d-%d, refimg %d x %d, reference frames %d-%d\n', ...
                info_path, obj.state.xpadstart, obj.state.xpadend, size(obj.state.motion_refimg, 1), ...
                size(obj.state.motion_refimg, 2), obj.state.motion_refframes(1), obj.state.motion_refframes(2));
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    end % end of method

    methods (Access=protected)
        function frames = demoframes(obj, loadstart, groupz)
            %DEMOFRAMES  ~5% of the frames as whole groupz blocks, starts spread by linspace
            total_frames = obj.info.fcount - loadstart + 1;
            n_chunks     = max(5, round(total_frames * 0.05 / groupz));
            chunk_starts = unique(round(linspace(loadstart, ...
                               obj.info.fcount - groupz + 1, n_chunks)));
            frames = reshape((chunk_starts(:) + (0:groupz-1))', 1, []);
        end

        function [stack, xpadstart, xpadend] = demoprepare(obj, stack)
            %DEMOPREPARE  pshift - findpadding (-2048 fill) - crop - group average - motionpreprocess
            %   Caller: mdf_xymovie.demomotion, mdf_xymovie.restore
            stack = mdf_pshiftcorrection(stack, obj.state.xshift);
            [xpadstart, xpadend] = mdf.findpadding(stack);
            stack = pre_groupaverage(stack(:, xpadstart:xpadend, :), obj.state.groupz);
            stack = mdf_motionpreprocess(stack, obj.state.motion_medfilt, obj.state.motion_clahe, ...
                obj.state.motion_clahe_size, obj.state.motion_wiener);
        end

        function [own_start, own_stop, read_start, read_stop] = readwindow(obj)
            %READWINDOW  the parent's own span, loaded with one group more each side than medfilt3 reaches
            %   medfilt3 reaches floor(z/2) pages either way and the interpolation reads one
            %   page beyond, so the load carries one more group than that on both sides.
            [own_start, own_stop] = readwindow@mdf(obj);
            overlap    = (floor(obj.state.motion_medfilt(3) / 2) + 1) * obj.state.groupz;
            read_start = max(obj.state.loadstart, own_start - overlap);
            read_stop  = min(obj.state.loadend,   own_stop  + overlap);
        end

        function [unit, page_keys, page_step] = pageaxis(obj)
            %PAGEAXIS  an XY Movie's page axis is time: one page is groupz frames
            unit      = ["um" "um" "sec"];
            page_keys = ["frames" "finterval"];
            page_step = obj.state.groupz / obj.info.fps;
        end

        function [frame_pos, col_idx] = tablecolumns(obj, own_start, own_stop)
            %TABLECOLUMNS  where own frames sit on the drift table, and the columns that reaches
            %   pre_applymotion's linspace: the step is (n_page-1)/(n_total-1), not 1/groupz;
            %   see CLAUDE_LOG.md 2026-08-30 linspace 의 걸음
            n_total = obj.state.loadend - obj.state.loadstart + 1;
            n_page  = n_total / obj.state.groupz;
            table_step = (n_page - 1) / (n_total - 1);
            frame_pos  = 1 + ((own_start:own_stop) - obj.state.loadstart) * table_step;
            col_idx    = max(1, floor(frame_pos(1))) : min(n_page, ceil(frame_pos(end)));
        end

    end

end

function value = infofield(saved, key, default)
%INFOFIELD  One field of the loaded info, or the default when the file predates the key.
%
% IN   saved    1 x 1 struct   from io_loadinfo
%      key      1 x n char     the field to return
%      default  1 x n char     what an absent key means, as text the caller converts
% OUT  value    1 x n char
    if isfield(saved, key)
        value = saved.(key);
    else
        value = default;
    end
end

