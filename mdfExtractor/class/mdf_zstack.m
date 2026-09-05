classdef mdf_zstack < mdf
    %MDF_ZSTACK  An Image Stack: planes zinter apart, each registered to the one before it on the way to disk

    properties
        drifttable = zeros(4, 0)    % 4 x n_plane    dft_registration rows, plane k against k-1; as mdf_xymovie
    end

    methods
        function obj = mdf_zstack(pathlist)
            obj@mdf(pathlist);
            obj = obj.init();
            if  strcmp(obj.info.scanmode,'XY Movie') == 1
                disp('use mdf_xymovie class')
            end
        end

        function [obj, demo] = demoload(obj, refimgchannel, option)
            %DEMOLOAD  a spread of planes off one channel, then the pixel shift off them
            %
            % OUT  obj          state gains motion_refchannel, xshift
            %      demo.raw     H x W x T int16   as read, margins still at -2048
            %      demo.frames  1 x T double      the plane of each
            arguments
                obj
                refimgchannel (1,1) {mustBeNumeric}
                option.n_plane (1,1) {mustBeNumeric} = 20   % planes the demo reads, spread over the window
            end
            obj.state.motion_refchannel = refimgchannel;
            obj.state.ch2read = refimgchannel;
            demo.frames = unique(round(linspace(obj.state.loadstart, obj.state.loadend, option.n_plane)));
            mobj = obj.openmdf();
            demo.raw = mdf_readframes(mobj, obj.state.motion_refchannel, demo.frames);
            delete(mobj);
            obj.state.xshift = mdf_pshiftexplorer(demo.raw);
        end

        function [obj, demo] = demomotion(obj, demo)
            %DEMOMOTION  pshift - findpadding (-2048 fill) - crop, then the box the registration reads
            %
            % OUT  obj             state gains xpadstart, xpadend, motion_vertices
            %      demo.processed  H x W x T int16   what the box was drawn on
            demo.processed = mdf_pshiftcorrection(demo.raw, obj.state.xshift);
            [obj.state.xpadstart, obj.state.xpadend] = mdf.findpadding(demo.processed);
            demo.processed = demo.processed(:, obj.state.xpadstart:obj.state.xpadend, :);
            [obj.state.motion_vertices, ~] = mdf_rectangle_polygon(demo.processed, 'rectangle');
        end

        function drifttable = getdrifttable(obj)
            %GETDRIFTTABLE  each own plane against the one before it, into this read's columns
            %
            % OUT  drifttable  4 x n double   obj.drifttable with this read's planes written in;
            %                                 the recording's first plane is its own anchor, 0
            [own_start, own_stop, read_start, ~] = obj.readwindow();
            offset   = own_start - read_start;               % 1 once the plane before is loaded too
            own_cols = (own_start : own_stop) - obj.state.loadstart + 1;
            read_drift = pre_estimatemotion(obj.stack, obj.stack(:, :, 1), obj.state.motion_vertices, true);
            drifttable = obj.drifttable;
            drifttable(:, own_cols) = read_drift(:, offset + (1:numel(own_cols)));   % the plane after is read too, unused
        end

        function stack = correctdrift(obj)
            %CORRECTDRIFT  each own plane moved by the sum of the informed steps before it, so all sit where plane 1 sits
            %
            % OUT  stack  H x W x n int16   the own planes only; -2048 where the shift moved nothing in
            %
            %   A step whose regerror is above motion_maxerror measured nothing (two planes with no
            %   shared structure) and counts as 0; summed as measured it walked a whole stack
            %   sideways, see CLAUDE_LOG.md
            [own_start, own_stop, read_start, ~] = obj.readwindow();
            offset     = own_start - read_start;
            own_cols   = (own_start : own_stop) - obj.state.loadstart + 1;
            informed   = obj.drifttable(1, :) < obj.state.motion_maxerror;   % 1 x n_plane logical
            step       = obj.drifttable(3:4, :);                              % 2 x n_plane, row then column
            step(:, ~informed) = 0;
            cumulative = cumsum(step, 2);
            n_own = numel(own_cols);
            stack = zeros(size(obj.stack, 1), size(obj.stack, 2), n_own, 'like', obj.stack);
            for k = 1:n_own
                shift = round(cumulative(:, own_cols(k)));
                stack(:, :, k) = imtranslate(obj.stack(:, :, offset + k), [shift(2), shift(1)], ...
                    'FillValues', -2048);
            end
        end

        function savemotion(obj)
            %SAVEMOTION  write dft_registration's four rows in its order -- the steps, not their sum
            %   The same body as mdf_xymovie.savemotion; a change here goes there too
            info.driftestimation_fps = num2str(obj.info.fps / obj.state.groupz);   % char, as written
            motion_rows.regerror  = obj.drifttable(1,:);   % sqrt(1-|CCmax|^2/(E1*E2)), 0 = identical
            motion_rows.diffphase = obj.drifttable(2,:);   % angle(CCmax), 0 for real images
            motion_rows.rowshift  = obj.drifttable(3,:);   % plane k against k-1; correctdrift sums them
            motion_rows.colshift  = obj.drifttable(4,:);
            motion_path = fullfile(obj.state.save_folder, [obj.info.mdfName(1:end-4), '_motion.txt']);
            io_1d2txt(motion_path, '--- Motion info ---', info, '--- Motion table ---', motion_rows);
        end

        function info = state2info(obj)
            %STATE2INFO  the parent's window and rate, then what demoload and demomotion settled
            info = state2info@mdf(obj);
            info.xshift            = obj.state.xshift;
            info.motion_refchannel = obj.state.motion_refchannel;
            info.motion_vertices   = strjoin(string(reshape(obj.state.motion_vertices', 1, [])));   % by rows
            info.motion_maxerror   = obj.state.motion_maxerror;
        end
    end

    methods (Access = protected)
        function overlap = overlapframes(obj) %#ok<MANU>
            %OVERLAPFRAMES  the plane before, so the first own plane has its partner
            overlap = 1;
        end

        function obj = defaultstate(obj)
            %DEFAULTSTATE  the parent's, then the regerror above which a plane-to-plane step measured nothing
            obj = defaultstate@mdf(obj);
            obj.state.motion_maxerror = 0.5;   % dft_registration's error, sqrt(1-|CCmax|^2/(E1*E2)); 1 = no correlation
        end

        function [unit, page_keys, page_step] = pageaxis(obj)
            %PAGEAXIS  an Image Stack's page axis is depth: one page is zinter
            unit      = ["um" "um" "um"];
            page_keys = ["slices" "spacing"];
            page_step = util_unit2double(obj.info.zinter);   % um between planes
        end
    end
end
