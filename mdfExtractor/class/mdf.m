classdef mdf
    %MDF Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        info
        stack
        mobj % auto
        state = struct( ...
            'loadstart', 1,...
            'ch2read',  1);
    end
    
    methods
        function obj = mdf(option)
            arguments
                option.objective = true;
                option.wavelength = 0;
            end
            %MDF Construct an instance of this class
            %   Detailed explanation goes here
            [obj.info, obj.mobj] = mdf_init();
            %   Default img frame reading parameter from beginning to end
            obj.state.loadend = obj.info.fcount;
            obj.state.save_folder = fullfile(obj.info.mdfPath, obj.info.mdfName(1:end-4));
            if ~option.objective
                obj.info.objname = '<Unknown Objective>';
            end
            if option.wavelength > 0
                obj.info.excitation = option.wavelength;
            end
            if strcmp(obj.info.objname , '<Unknown Objective>')
                disp('Objective information is missing')
            [obj.info.objname, obj.info.objpix] = mdf_objectiveselector();
            obj.info.objpix = obj.info.objpix/str2double(obj.info.zoom(1:end-1));
            end
            if ~exist(obj.state.save_folder, 'dir')
                mkdir(obj.state.save_folder);
            end
        end
        
       
        function zstack = loadframes(obj)
                    zstack = mdf_readframes(obj.mobj,obj.state.ch2read,[obj.state.loadstart, obj.state.loadend]);
                    disp('Padding removal')
                    zstack = zstack(:,obj.state.xpadstart:obj.state.xpadend,:);
                    % xshift correction
                    disp('Pixel shift correction')
                    zstack = mdf_pshiftcorrection(zstack,obj.state.xshift);
                    zstack(zstack<0) = 0; % Thresholding negative values to be 0 (as inverted PMT output and what mSCAN shows is positive value.)
        end

        function logic = showstack(obj)
            logic = util_checkstack(obj.stack);
        end

        function info = savetiff(obj)
            info = obj.info;
            info.savefps = info.fps/obj.state.groupz; 
            if isa(info.objpix,'double')
                save_resolution = [info.objpix,info.objpix,1 / info.savefps]; % [x,y,z resolution um, sec]
            else
                save_resolution = [str2double(info.objpix(1:end-2)),str2double(info.objpix(1:end-2)),1 / info.savefps]; % [x,y,z resolution um, sec]
            end
            % Construct full file path
            save_path = fullfile(obj.state.save_folder, [info.mdfName(1:end-4),sprintf('_ch%d.tif',obj.state.ch2read)]);
            io_savetiff(obj.stack, save_path, save_resolution)
        end

        function saveinfo(obj)
            disp('save info')
            io_saveinfo(obj.info,obj.state.save_folder);
        end
           
    end
end

