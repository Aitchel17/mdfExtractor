classdef mdf_zstack < mdf
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods
        function obj = mdf_zstack(pathlist)
            obj@mdf(pathlist);
            if  strcmp(obj.info.scanmode,'XY Movie') == 1
                disp('use mdf_xymovie class')
            end
            try
                rawzstack = mdf_readframes(obj.mobj,obj.state.ch2read,[obj.state.loadstart, obj.state.loadend]);
            catch
                rawzstack = mdf_readframes(obj.mobj,obj.state.ch2read,[obj.state.loadstart, obj.state.loadend]);
            end

            [obj.state.xpadstart, obj.state.xpadend] = mdf.findpadding(rawzstack);
        end
        
    end
end

