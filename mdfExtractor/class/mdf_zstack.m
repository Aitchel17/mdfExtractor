classdef mdf_zstack < mdf
    % mdf_zstack load
    
    properties
    end
    
    methods
        function obj = mdf_zstack(mdfpath)
            obj@mdf(mdfpath);
            if  strcmp(obj.info.scanmode,'XY Movie') == 1
                disp('use mdf_xymovie class')
            end
            mobj = obj.openmdf();
            frames = obj.state.loadstart : obj.state.loadend;
            rawzstack = mdf_readframes(mobj, obj.state.ch2read, frames);
            delete(mobj);

            [obj.state.xpadstart, obj.state.xpadend] = mdf.findpadding(rawzstack);
        end
        
    end
end

