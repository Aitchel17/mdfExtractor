classdef mdf_xy_mutiplane < mdf_xymovie
    %UNTITLED2 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods
        function obj = mdf_xy_mutiplane()
            obj@mdf_xymovie();
            obj.state.plane2read = 1;
        end

        function obj = updatestate(obj,parameters)
            % Change state.loadstart, and state.loadend if necessary
            % Input: sec --> converted to frame using info.fps
            % (If want to set offset)

            % Image loading parameter
            arguments
                obj              
                parameters.loadstart(1,1) {mustBeNumeric} = obj.state.loadstart
                parameters.loadend(1,1) {mustBeNumeric}   = obj.state.loadend
                parameters.ch2read (1,1) {mustBeNumeric} = obj.state.ch2read
                parameters.num_plane (1,1) {mustBeNumeric} = obj.state.num_plane
                parameters.plane2read (1,1) {mustBeNumeric} = obj.state.plane2read
                parameters.groupz = obj.state.groupz
            end
          
            obj.state.ch2read = parameters.ch2read;
            obj.state.loadstart = parameters.loadstart;
            obj.state.loadend = parameters.loadend;
            obj.state.groupz = parameters.groupz;
            obj.state.num_plane = parameters.num_plane;
            obj.state.plane2read = parameters.plane2read;

            if obj.state.loadend > obj.info.fcount % beyond the last frame, read to the end
                disp('Duration exceed total frame, loadend set to the end')
                obj.state.loadend = obj.info.fcount;
            end
            if obj.state.loadstart < 1
                disp('frame start should above 1')
                obj.state.loadstart = 1;
            end
        end

        function [obj, demo] = demoload(obj, refimgchannel, refimgplane, option)
            %DEMOLOAD  load (loadstart : num_plane : fcount/20) + plane offset then determine pshift
            arguments
                obj
                refimgchannel (1,1) {mustBeNumeric}
                refimgplane (1,1) {mustBeNumeric}
                option.groupz (1,1) {mustBeNumeric} = obj.state.groupz
            end

            % set up
            obj.state.motion_refchannel = refimgchannel;
            obj.state.refplane   = refimgplane;
            obj.state.plane2read = refimgplane;
            obj.state.ch2read    = refimgchannel;
            obj.state.groupz     = option.groupz;

            % Prepare loading idx
            demo.fend   = round((obj.info.fcount - obj.state.loadstart)/20);
            frames      = (obj.state.loadstart : obj.state.num_plane : demo.fend) + (obj.state.plane2read - 1);
            demo.frames = frames(frames <= demo.fend);
            % load frame
            mobj = obj.openmdf();
            demo.raw = mdf_readframes(mobj, obj.state.motion_refchannel, demo.frames);
            delete(mobj);   % the dialog below only needs the stack, not the file
            % determine pshift
            obj.state.xshift = mdf_pshiftexplorer(demo.raw);
        end

        function zstack = loadframes(obj)
            frames = (obj.state.loadstart : obj.state.num_plane : obj.state.loadend) + (obj.state.plane2read - 1);
            frames = frames(frames <= obj.state.loadend);
            mobj = obj.openmdf();
            zstack = mdf_readframes(mobj, obj.state.ch2read, frames);
            delete(mobj);
            disp('Padding removal')
            zstack = zstack(:,obj.state.xpadstart:obj.state.xpadend,:);
            % xshift correction
            disp('Pixel shift correction')
            zstack = mdf_pshiftcorrection(zstack,obj.state.xshift);
            % non negative
            disp('min subtraction for non negative array')
            zstack = zstack - min(zstack,[],'all');
        end
        
        function info = savetiff(obj)
            info = obj.info;
            % loadframes reads every num_plane-th frame, so a stored frame is
            % groupz * num_plane acquisition frames from the next
            info.savefps = info.fps/(obj.state.groupz * obj.state.num_plane);
            if isa(obj.info.objpix,'double')
                save_resolution = [obj.info.objpix,obj.info.objpix,1 / info.savefps]; % [x,y,z resolution um, sec]
            else
                save_resolution = [str2double(obj.info.objpix(1:end-2)),str2double(obj.info.objpix(1:end-2)),1 / info.savefps]; % [x,y,z resolution um, sec]
            end
            % Construct full file path
            save_path = fullfile(obj.state.save_folder, [obj.info.mdfName(1:end-4),sprintf('_ch%d.tif',obj.state.ch2read)]);

            if obj.state.num_plane ~= 1
                save_path = fullfile(obj.state.save_folder, [obj.info.mdfName(1:end-4),sprintf('_ch%dplane%d_%d.tif',obj.state.ch2read,obj.state.num_plane,obj.state.plane2read)]);
            end
            % save
            io_savetiff(obj.stack, save_path, save_resolution)
        end

      
    end
end

