classdef mdf_xymovie < mdf
    %MDF_ Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        analog
        drifttable
    end
    
    methods
        function obj = mdf_xymovie()
            obj@mdf();
            [obj.analog.data, obj.analog.info] = mdf_readanalog(obj.mobj);
            obj.state.groupz = 10;
            obj.state.xpadstart = 1;
            obj.state.xpadend = obj.info.fwidth;
            obj.state.xshift = 0;
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
                parameters.groupz = obj.state.groupz
            end
          
            state = obj.state;
            state.ch2read = parameters.ch2read;
            state.loadstart = parameters.loadstart;
            state.loadend = parameters.loadend;
            state.groupz = parameters.groupz;

            if state.loadend > obj.info.fcount % if calculated frame end exceed end of frame, load from start to the end
                disp('Duration exceed total frame, loadend set to the end')
                state.loadend = obj.info.fcount;
            end
            if state.loadstart < 1 % if calculated frame end exceed end of frame, load from start to the end
                disp('frame start should above 1')
                state.loadstart = 1;
            end
        end

        function info = state2info(obj, fieldname)
            arguments
                obj
                fieldname.loadstart = true
                fieldname.loadend = true
                fieldname.xshift = true
                fieldname.refframe = true
                fieldname.refchannel = true
                fieldname.motionvertices = true
                fieldname.groupz = true
            end
            
            % Initialize info with the existing obj.info
            info = obj.info;
            
            % Get all field names from fieldname structure
            fields = fieldnames(fieldname);
            
            % Iterate over the field names and update info if the fieldname value is true
            for i = 1:numel(fields)
                field = fields{i}; % Get the current field name
                if fieldname.(field) % Check if the field is flagged as true
                    if strcmp(field, 'motionvertices') % Special case for motionvertices
                        info.(field) = strjoin(string(reshape(obj.state.motionvertices', 1, [])));
                    else
                        info.(field) = obj.state.(field); % General case
                    end
                end
            end
        end



        function [state,demo] = demo(obj,refimgchannel,option)
            arguments
                obj
                refimgchannel (1,1) {mustBeNumeric}
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
            state.ch2read = refimgchannel;
            state.groupz = option.groupz;
            demo.fend = round((obj.info.fcount - state.loadstart)/20);
            demo.stack = mdf_readframes(obj.mobj,state.refchannel,[state.loadstart, demo.fend]); % 0
            [state, demo] = mdf_xymovie.staticdemo(demo,state);
        end

        function estimated_drifttable = getdrifttable(obj)
                % Preprcocessing (Padding removal -> post pixel shift correction -> Trim -> Non Negative -> group average -> medfilt3)
                % group averaging
                disp('group averaging')
                zstack = pre_groupaverage(obj.stack, obj.state.groupz); % denoise by group averaging
                % median filter xy3 z5 pixel
                disp('3D median filtering')
                zstack = medfilt3(zstack,[3,3,5]); % denoise by 3d median filter
                estimated_drifttable = pre_estimatemotion(zstack,obj.state.refimg,obj.state.motionvertices);
        end

        function [zstack, applied_drifttable] = correctdrift(obj)
            [zstack, applied_drifttable] = pre_applymotion(obj.stack,obj.drifttable);
        end

        function zstack = afterprocess(obj,option)
            arguments
                obj
                option.thresholding = false
            end
            % Group averaging
            zstack = pre_groupaverage(obj.stack,obj.state.groupz);
            % Thresholding
            if option.thresholding
                zstack = pre_thresholding(zstack,cutoff=1,cutting_size=4);
            end
        end

        function saveanalog(obj)
            filename = fullfile(obj.state.save_folder, [obj.info.mdfName(1:end-4),'_analog.txt']);
            analogdata = obj.analog.data;
            analoginfo = obj.analog.info;
            fileID = fopen(filename, 'w');
            
            % Header start
            fprintf(fileID, '--- Analog Info ---\n');
            % Write the struct fields and their values
            fieldNames = fieldnames(analoginfo); % Get the field names
            for i = 1:numel(fieldNames)
                fieldName = fieldNames{i};
                fieldValue = analoginfo.(fieldName);
                % Convert arrays/matrices to a string for writing
                if isnumeric(fieldValue)
                    fieldValueStr = mat2str(fieldValue); % Converts numbers to string
                elseif ischar(fieldValue)
                    fieldValueStr = fieldValue; % Keep strings as-is
                end
                % Write the field name and value to the file
                fprintf(fileID, '%s: %s\n', fieldName, fieldValueStr);
            end
            % end of header
             fprintf(fileID, '\n--- Analog Data ---\n');
            % Write the data row by row (field names as row names)
            channelNames = fieldnames(analogdata); % Field names are row names
            for i = 1:numel(channelNames)
                rowName = channelNames{i}; % Get the row name (field name)
                rowData = analogdata.(rowName); % Get the corresponding data
                rowData = mat2str(rowData); % Convert to a string
                % Write the row name and its data
                fprintf(fileID, '%s: %s\n', rowName, rowData);
            end
            % Close the file
            fclose(fileID);
        end


    end
    
    methods (Access=protected, Static)
        function [state, demo] = staticdemo(demo,state)
            [state.xpadstart,state.xpadend] = mdf.findpadding(demo.stack); % 1
            demo.stack(demo.stack<0) = 0;
            state.xshift = mdf_pshiftexplorer(demo.stack); % 2.1
            demo.stack = mdf_pshiftcorrection(demo.stack,state.xshift); % 2.2
            demo.stack = pre_groupaverage(demo.stack(:,state.xpadstart:state.xpadend,:), state.groupz); % 3
            demo.stack = medfilt3(demo.stack,[3,3,5]); % 4
            % 5
            qualitycontrol = false;
            while qualitycontrol == false
                [state.motionvertices, state.refframe] = mdf_rectangle_polygon(demo.stack,'rectangle');
                state.refimg = demo.stack(:,:,state.refframe);
                demo.drift_table = pre_estimatemotion(demo.stack,state.refimg,state.motionvertices);
                [demo.correctedstack, demo.ip_Drifttable] = pre_applymotion(demo.stack,demo.drift_table);
                qualitycontrol = util_checkstack(demo.correctedstack);
            end
        end
    end
end

