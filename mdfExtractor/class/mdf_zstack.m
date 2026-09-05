classdef mdf_zstack < mdf
    %MDF_ZSTACK  An Image Stack: planes zinter apart, written one read at a time

    methods
        function obj = mdf_zstack(pathlist)
            obj@mdf(pathlist);
            obj = obj.init();
            if  strcmp(obj.info.scanmode,'XY Movie') == 1
                disp('use mdf_xymovie class')
            end
        end

        function obj = probepad(obj)
            %PROBEPAD  the padding the sinusoidal correction left, off the window's first frames
            %   Caller: mdf_zstack_main
            n_probe = 8;
            frames  = obj.state.loadstart : min(obj.state.loadstart + n_probe - 1, obj.state.loadend);
            mobj  = obj.openmdf();
            probe = mdf_readframes(mobj, obj.state.ch2read, frames);
            delete(mobj);
            [obj.state.xpadstart, obj.state.xpadend] = mdf.findpadding(probe);
        end
    end

    methods (Access = protected)
        function [unit, page_keys, page_step] = pageaxis(obj)
            %PAGEAXIS  an Image Stack's page axis is depth: one page is zinter
            unit      = ["um" "um" "um"];
            page_keys = ["slices" "spacing"];
            page_step = util_unit2double(obj.info.zinter);   % um between planes
        end
    end
end
