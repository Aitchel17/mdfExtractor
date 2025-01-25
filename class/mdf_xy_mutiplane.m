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

        function state = updatestate(obj,parameters)
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
          
            state = obj.state;
            state.ch2read = parameters.ch2read;
            state.loadstart = parameters.loadstart;
            state.loadend = parameters.loadend;
            state.groupz = parameters.groupz;
            state.num_plane = parameters.num_plane;
            state.plane2read = parameters.plane2read;

            if state.loadend > obj.info.fcount % if calculated frame end exceed end of frame, load from start to the end
                disp('Duration exceed total frame, loadend set to the end')
                state.loadend = obj.info.fcount;
            end
            if state.loadstart < 1 % if calculated frame end exceed end of frame, load from start to the end
                disp('frame start should above 1')
                state.loadstart = 1;
            end
        end

        function [state,demo] = demo(obj,refimgchannel,refimgplane,option)
            arguments
                obj
                refimgchannel (1,1) {mustBeNumeric}
                refimgplane (1,1) {mustBeNumeric}
                option.groupz (1,1) {mustBeNumeric} = 10
            end

            % update info, adding 
            %   a. pixel shift
            %   b. padding coordination
            %   c. group averaging info
            %   d. plane info if its multiplane
            % for inspection purpose demo struct
    
            % 0. first 5% of video to choose representative region fo
            % 1. pad correction
            % 2. pixel shift correction  
            % 3. groupaveraging after padding removal
            % 4. denoise using median filter 3d [xy:3pix,z:5pix]
            % 5. drift correction estimation until work well
    
            state = obj.state;
            state.refchannel = refimgchannel;
            state.refplane  = refimgplane;
            state.plane2read = refimgplane;
            state.ch2read = refimgchannel;
            state.groupz = option.groupz;
            demo.fend = round((obj.info.fcount - state.loadstart)/20);
            demo.stack = mdf_readframes(obj.mobj,state.refchannel,[state.loadstart, demo.fend],state.num_plane,state.plane2read); % 0
            [state, demo] = obj.staticdemo(demo,state);
        end

        function zstack = loadframes(obj)
            zstack = mdf_readframes(obj.mobj,obj.state.ch2read,[obj.state.loadstart, obj.state.loadend],obj.state.num_plane,obj.state.plane2read);
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
            info.savefps = info.fps/obj.state.groupz; 
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

