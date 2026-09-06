classdef mdf_zstack < mdf
    %MDF_ZSTACK  An Image Stack: planes zinter apart, each registered to the median of the corrected planes before it, both channels in one file

    properties
        drifttable = zeros(4, 0)    % 4 x n_plane    dft_registration rows, plane k against the running reference: an absolute shift, as mdf_xymovie
    end

    methods
        function obj = mdf_zstack(pathlist)
            obj@mdf(pathlist);
            obj = obj.init();
            if  strcmp(obj.info.scanmode,'XY Movie') == 1
                disp('use mdf_xymovie class')
            end
        end

        function obj = demoload(obj, refimgchannel, option)
            %DEMOLOAD  a spread of planes off one channel: the pixel shift off them (or the one given), then the padding
            %
            % IN   option.xshift  1 x 1 double   a pixel shift settled on another file; [] asks
            % OUT  obj            state gains motion_refchannel, xshift, xpadstart, xpadend
            arguments
                obj
                refimgchannel (1,1) {mustBeNumeric}
                option.n_plane (1,1) {mustBeNumeric} = 20   % planes the probe reads, spread over the window
                option.xshift = []
            end
            obj.state.motion_refchannel = refimgchannel;
            obj.state.ch2read = refimgchannel;
            frames = unique(round(linspace(obj.state.loadstart, obj.state.loadend, option.n_plane)));
            mobj = obj.openmdf();
            probe = mdf_readframes(mobj, obj.state.motion_refchannel, frames);
            delete(mobj);
            if isempty(option.xshift)
                obj.state.xshift = mdf_pshiftexplorer(probe);
            else
                obj.state.xshift = option.xshift;
            end
            probe = mdf_pshiftcorrection(probe, obj.state.xshift);
            [obj.state.xpadstart, obj.state.xpadend] = mdf.findpadding(probe);
        end

        function obj = demomotion(obj, option)
            %DEMOMOTION  the motion settings into state, then the table off the loaded stack, plane by plane against the running reference
            %   The whole stack is obj.stack, one read. Nothing is drawn or shown; the moved stack is judged
            %   afterwards from _motion.txt and the merged file
            %
            % IN   option.motion_refplanes   1 x 1 double   corrected planes before k whose median is k's reference
            %      option.motion_maxerror    1 x 1 double   regerror at or above which a plane measured nothing
            %      option.motion_medfilt     1 x 3 double   medfilt3 window [xy xy z] before estimating
            %      option.motion_clahe       1 x 1 logical
            %      option.motion_clahe_size  1 x 1 double   CLAHE tile side (px)
            %      option.motion_wiener      1 x 1 logical
            % OUT  obj              state gains the motion_* above; drifttable measured
            arguments
                obj
                option.motion_refplanes (1,1) {mustBeInteger, mustBePositive} = obj.state.motion_refplanes
                option.motion_maxerror (1,1) {mustBeNumeric} = obj.state.motion_maxerror
                option.motion_medfilt (1,3) {mustBeNumeric} = obj.state.motion_medfilt
                option.motion_clahe (1,1) logical = obj.state.motion_clahe
                option.motion_clahe_size (1,1) {mustBeNumeric} = obj.state.motion_clahe_size
                option.motion_wiener (1,1) logical = obj.state.motion_wiener
            end
            obj.state.motion_refplanes  = option.motion_refplanes;
            obj.state.motion_maxerror   = option.motion_maxerror;
            obj.state.motion_medfilt    = option.motion_medfilt;
            obj.state.motion_clahe      = option.motion_clahe;
            obj.state.motion_clahe_size = option.motion_clahe_size;
            obj.state.motion_wiener     = option.motion_wiener;
            obj.drifttable = obj.getdrifttable();
        end

        function [row_range, col_range] = getcropbounds(obj)
            %GETCROPBOUNDS  the region every plane still covers once moved by its summed steps
            %
            % OUT  row_range  1 x 2 double   [start end], inclusive
            %      col_range  1 x 2 double
            applied = round(obj.appliedshift(obj.drifttable));   % what correctdrift applies
            frame_size = [obj.info.fheight, obj.state.xpadend - obj.state.xpadstart + 1];
            [row_range, col_range] = pre_cropbounds([zeros(2, size(applied, 2)); applied], frame_size);
        end

        function drifttable = getdrifttable(obj)
            %GETDRIFTTABLE  motionpreprocess, then each plane against the median of the corrected planes before it
            %   A plane whose regerror reaches motion_maxerror measured nothing and keeps the shift of
            %   the plane before it; the corrected copy of every plane feeds the next references
            %
            % OUT  drifttable  4 x n double   obj.drifttable with this read's planes written in: dft_registration
            %                                 rows against the running reference, so rows 3-4 are absolute shifts;
            %                                 the recording's first plane is the anchor, 0
            [own_start, own_stop, read_start, ~] = obj.readwindow();
            offset   = own_start - read_start;               % planes before the first own one, read for the reference
            own_cols = (own_start : own_stop) - obj.state.loadstart + 1;
            prepared = mdf_motionpreprocess(obj.stack, obj.state.motion_medfilt, ...
                obj.state.motion_clahe, obj.state.motion_clahe_size, obj.state.motion_wiener);
            frame = [1 1; size(prepared, 2) 1; size(prepared, 2) size(prepared, 1); 1 size(prepared, 1)];
            n_read = size(prepared, 3);
            read_drift = zeros(4, n_read);
            applied = [0; 0];
            past = double(prepared(:, :, 1));                % H x W x up to motion_refplanes, corrected; NaN where a shift moved nothing in
            for k = 2:n_read
                reference = median(past, 3, 'omitnan');
                reference(isnan(reference)) = mean(reference, 'all', 'omitnan');
                read_drift(:, k) = pre_estimatemotion(prepared(:, :, k), reference, frame, false);
                if read_drift(1, k) < obj.state.motion_maxerror
                    applied = read_drift(3:4, k);
                end
                corrected = imtranslate(double(prepared(:, :, k)), [applied(2), applied(1)], 'FillValues', NaN);
                past = cat(3, past, corrected);
                if size(past, 3) > obj.state.motion_refplanes
                    past = past(:, :, 2:end);
                end
            end
            drifttable = obj.drifttable;
            drifttable(:, own_cols) = read_drift(:, offset + (1:numel(own_cols)));
        end

        function stack = correctdrift(obj, row_range, col_range)
            %CORRECTDRIFT  each own plane moved by its applied shift, then cut to the region
            %
            % IN   row_range  1 x 2 double   rows kept after the move, from getcropbounds (default: all)
            %      col_range  1 x 2 double   columns kept
            % OUT  stack      H x W x n int16   the own planes only; -2048 where the shift moved nothing in
            arguments
                obj
                row_range (1,2) {mustBeNumeric} = [1, size(obj.stack, 1)]
                col_range (1,2) {mustBeNumeric} = [1, size(obj.stack, 2)]
            end
            [own_start, own_stop, read_start, ~] = obj.readwindow();
            offset     = own_start - read_start;
            own_cols   = (own_start : own_stop) - obj.state.loadstart + 1;
            applied = obj.appliedshift(obj.drifttable);
            n_own = numel(own_cols);
            stack = zeros(row_range(2) - row_range(1) + 1, col_range(2) - col_range(1) + 1, n_own, 'like', obj.stack);
            for k = 1:n_own
                shift = round(applied(:, own_cols(k)));
                moved = imtranslate(obj.stack(:, :, offset + k), [shift(2), shift(1)], 'FillValues', -2048);
                stack(:, :, k) = moved(row_range(1):row_range(2), col_range(1):col_range(2));
            end
        end

        function savetiff(obj, other_stack)
            %SAVETIFF  both channels into one file, a plane's two channels side by side: page (k-1)*2 + channel
            %
            % IN   other_stack  H x W x n int16   the channel not on ch2read, moved and cut the same way
            channel_stacks = cell(1, 2);
            channel_stacks{obj.state.ch2read}     = obj.stack;
            channel_stacks{3 - obj.state.ch2read} = other_stack;
            n_plane = size(obj.stack, 3);
            tags = obj.label_tiftag(n_plane, [size(obj.stack, 1), size(obj.stack, 2)], 2);
            for k = 1:n_plane
                for channel = 1:2
                    mdf.writepage(obj.state.tiff, tags, (k - 1) * 2 + channel, ...
                        mdf.touint16(channel_stacks{channel}(:, :, k)));
                end
            end
            fprintf('%s: %d planes x 2 channels\n', obj.info.mdfName(1:end-4), n_plane);
        end

        function savemotion(obj)
            %SAVEMOTION  write dft_registration's four rows in its order -- as measured, before the gate
            %   The same body as mdf_xymovie.savemotion; a change here goes there too
            info.driftestimation_fps = num2str(obj.info.fps / obj.state.groupz);   % char, as written
            motion_rows.regerror  = obj.drifttable(1,:);   % sqrt(1-|CCmax|^2/(E1*E2)), 0 = identical
            motion_rows.diffphase = obj.drifttable(2,:);   % angle(CCmax), 0 for real images
            motion_rows.rowshift  = obj.drifttable(3,:);   % against the running reference; appliedshift holds it through gated planes
            motion_rows.colshift  = obj.drifttable(4,:);
            motion_path = fullfile(obj.initdir(), [obj.info.mdfName(1:end-4), '_motion.txt']);
            io_1d2txt(motion_path, '--- Motion info ---', info, '--- Motion table ---', motion_rows);
        end

        function info = state2info(obj)
            %STATE2INFO  the parent's window and rate, then what demoload and demomotion settled
            info = state2info@mdf(obj);
            info.xshift            = obj.state.xshift;
            info.motion_refchannel = obj.state.motion_refchannel;
            info.motion_refplanes  = obj.state.motion_refplanes;
            info.motion_maxerror   = obj.state.motion_maxerror;
            info.motion_medfilt    = strjoin(string(obj.state.motion_medfilt));   % writetable wants a scalar
            info.motion_clahe      = obj.state.motion_clahe;
            info.motion_clahe_size = obj.state.motion_clahe_size;
            info.motion_wiener     = obj.state.motion_wiener;
        end
    end

    methods (Access = protected)
        function name = tiffname(obj)
            %TIFFNAME  one file for the stack, both channels in it
            name = [obj.info.mdfName(1:end-4), '_merged.tif'];
        end

        function applied = appliedshift(obj, drifttable)
            %APPLIEDSHIFT  each plane's shift as applied: its own where it measured something, else the plane before's
            %   Caller: mdf_zstack.correctdrift, mdf_zstack.getcropbounds; getdrifttable keeps the same rule as it goes
            %
            % IN   drifttable  4 x n double   dft_registration rows against the running reference
            % OUT  applied     2 x n double   row then column shift, for every plane
            informed = drifttable(1, :) < obj.state.motion_maxerror;   % 1 x n logical
            applied  = zeros(2, size(drifttable, 2));
            for k = 2:size(drifttable, 2)
                if informed(k)
                    applied(:, k) = drifttable(3:4, k);
                else
                    applied(:, k) = applied(:, k - 1);
                end
            end
        end

        function overlap = overlapframes(obj)
            %OVERLAPFRAMES  the planes the first own plane's reference is made of; the chain reads the whole stack at once
            overlap = obj.state.motion_refplanes;
        end

        function obj = defaultstate(obj)
            %DEFAULTSTATE  the parent's, the preprocess before estimating, the reference depth, and the regerror gate
            obj = defaultstate@mdf(obj);
            obj.state.motion_medfilt    = [1, 1, 1];   % 1 x 3, medfilt3 window [xy xy z]; 1 = off. A median ahead of a plane-to-plane estimate reads 0, see CLAUDE_LOG.md
            obj.state.motion_clahe      = false;
            obj.state.motion_clahe_size = 64;          % CLAHE tile side (px)
            obj.state.motion_wiener     = false;       % wiener2 and the low-pass after it
            obj.state.motion_refplanes  = 5;           % corrected planes whose median is the next plane's reference
            obj.state.motion_maxerror   = 0.99;        % regerror sqrt(1-rho^2) at or above which a plane measured nothing; noise against noise reads 1
        end

        function [unit, page_keys, page_step] = pageaxis(obj)
            %PAGEAXIS  an Image Stack's page axis is depth: one page is zinter
            unit      = ["um" "um" "um"];
            page_keys = ["slices" "spacing"];
            page_step = util_unit2double(obj.info.zinter);   % um between planes
        end
    end
end
