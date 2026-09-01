classdef mdf
    % Make mdffile connection using 
    properties
        info
        stack
        state = struct( ...
            'loadstart', 1,...
            'ch2read',  1 ...
            );
    end

    methods
        function obj = mdf(paths,objective,wavelength)
            arguments
                paths = [];
                objective = true;
                wavelength = 0;
            end
            % 0. Get mdf path to open
            if isempty(paths)
                [mdfName, mdfPath] = uigetfile({'*.mdf'});
                mdfPath = fileparts(fullfile(mdfPath, mdfName));
            elseif ischar(paths) == 1
                [mdfPath, stem, ext] = fileparts(paths);
                mdfName = [stem, ext];
            else
                disp(class(paths))
                error('mdf:paths', 'paths must be a char row or empty');
            end
            obj.info.mdfName = mdfName;
            obj.info.mdfPath = mdfPath;
            % 1. open mdf
            mobj = obj.openmdf();
            % 2. gather information
            read_info = mdf_get2pinfo(mobj);
            % 3. close the connection, so nothing else is blocked from the file
            delete(mobj);
            % name and path stay first, so _info.txt opens with which file it is
            obj.info = util_mergestruct(obj.info, read_info);
            fprintf('%s %s is loaded\n', obj.info.scanmode, obj.info.mdfName);
            % 4. default setup
            obj.state.loadend = obj.info.fcount; % read to end
            % Saving folder path
            obj.state.save_folder = fullfile(obj.info.mdfPath, obj.info.mdfName(1:end-4));
            obj.state.xpadstart = 1; % no left crop
            obj.state.xpadend = obj.info.fwidth; % no right crop
            obj.state.xshift = 0; % no pixel shift
            obj.state.groupz = 1; % no frame averaging
            % 5. complete imaging parameter
            if ~objective
                obj.info.objname = '<Unknown Objective>';
            end
            if wavelength > 0
                obj.info.excitation = wavelength;   % Wavelength
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
            % 0. Set which frames to read
            frames      = obj.state.loadstart : obj.state.loadend;
            n_frame     = numel(frames);
            % 1. Calculate chunk number from chunk size
            chunk_megabytes = 256;       % too small (overhead) or big chunk (big array modification)
            pixel_megabytes = 2 / 1e6;   % int16
            frame_megabytes = obj.info.fheight * obj.info.fwidth * pixel_megabytes;
            chunk_frames    = max(1, floor(chunk_megabytes / frame_megabytes));
            chunk_frames    = min(chunk_frames, n_frame);
            n_chunk         = ceil(n_frame / chunk_frames);
            % 2. open .mdf file
            mobj = obj.openmdf();
            % 3. Chunk run load - pad removal - pshift correction
            %    Negatives are kept. The PMT baseline sits near 0 and the noise
            %    swings both ways, so clipping here and then averaging rectifies:
            %    measured, it lifts a dim pixel by 97 counts and a bright one by 4
            zstack = [];   % h x w x n_frame, allocated once the corrected width is known
            for chunk_idx = 1:n_chunk
                frame_idx = (chunk_idx-1)*chunk_frames + 1 : min(chunk_idx*chunk_frames, n_frame); % 3.0 make idx array
                chunk = mdf_readframes(mobj, obj.state.ch2read, frames(frame_idx)); % 3.1 read frame
                chunk = chunk(:, obj.state.xpadstart:obj.state.xpadend, :); % 3.2 pad removal
                % 3.3 pshift correction
                if obj.state.xshift ~= 0
                    chunk = mdf_pshiftcorrection(chunk, obj.state.xshift);
                end

                if isempty(zstack)
                    [h, w, ~] = size(chunk);
                    zstack = zeros(h, w, n_frame, 'like', chunk);
                end
                zstack(:, :, frame_idx) = chunk; %#ok<AGROW> preallocated above
                fprintf('%.2f%% loaded\n', frame_idx(end) * 100 / n_frame);
            end
            % 3. close the connection
            delete(mobj);
        end

        function logic = showstack(obj)
            logic = mdf.checkstack(obj.stack);
        end

        function info = savetiff(obj)
            info = obj.info;
            info.savefps = info.fps/obj.state.groupz;
            %%
            if strcmp(obj.info.scanmode,'Image Stack')
                info.savefps = str2double(obj.info.zinter(1:end-2));
            end

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
            saveinfo = obj.info;
            saveinfo.savedate = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
            infoFields = fieldnames(saveinfo);
            infoValues = struct2cell(saveinfo);
            table_info = table(infoFields, infoValues, 'VariableNames', {'Field', 'Value'});

            % Construct full file path
            save_infopath = fullfile(obj.state.save_folder, [saveinfo.mdfName(1:end-4),'_info.txt']);
            % Write the table to an Excel file (overwrite the file initially)
            writetable(table_info, save_infopath);
        end
    end

    methods (Access=protected)
        function mobj = openmdf(obj)
            % return mobj, connected with .mdf by ActiveX
            mobj = actxserver('MCSX.Data');
            mobj.OpenMCSFile(fullfile(obj.info.mdfPath, obj.info.mdfName));
        end
    end

    methods (Access=protected, Static)
        function [start_x,end_x] = findpadding(frames)
            %% find padding caused by sinusoidal correction
            mean_x = mean(frames,[1,3]); % calculate mean value of y, z axis (y,x,z)
            tmp.nzloc = find(mean_x~=-2048); % find location of value not -2048
            start_x = tmp.nzloc(1); % start point of non zero
            end_x = tmp.nzloc(end); % end point of non zero
        end

        function [state] = checkstack(stack, window_title)
            arguments
                stack
                window_title = 'Stack Explorer'
            end
            % just for inspection purpose

            % Create the main figure
            stack = double(stack);
            min_val = min(stack,[],'all');
            max_val = max(stack,[],'all');
            stack = (stack - min_val) / (max_val - min_val) * 65535;
            stack = uint16(stack);
            state = false;

            fig = uifigure('Name', window_title, 'Position', [100, 100, 600, 400]);

            % Create panels for controls and image display
            imgPanel = uipanel(fig, 'Title', 'Slice Viewer', 'Position', [20, 120, 560, 260]);
            controlPanel = uipanel(fig, 'Title', 'Console', 'Position', [20, 20, 560, 100]);

            % Display the stack using sliceViewer
            hStack = sliceViewer(stack, 'Parent', imgPanel);

            % Extract the underlying axes object from the sliceViewer
            hAxes = getAxesHandle(hStack);

            % Add a label for the intensity range slider
            uilabel(controlPanel, 'Text', 'Intensity Range:', 'Position', [20, 60, 100, 20]);

            % Add a range slider for adjusting intensity range
            intensitySlider = uislider(controlPanel, 'range',...
                'Position', [130, 65, 400, 3], ...
                'Limits', [0, 65535], ...
                'Value', [0, 65535], ...
                'MajorTicks', [], ...
                'Orientation', 'horizontal', ...
                'ValueChangedFcn', @(src, event) updatefig(hAxes, src.Value));

            % Add instructions label
            uilabel(controlPanel, ...
                'Text', 'Adjust intensity and draw a rectangle around ROI. Then click Confirm.', ...
                'Position', [20, 20, 500, 20], ...
                'HorizontalAlignment', 'left');

            % Add a Confirm button
            uibutton(controlPanel, ...
                'Text', 'Confirm', ...
                'Position', [480, 10, 70, 30], ...
                'ButtonPushedFcn', @(src, event) confirm()); % Resume execution when clicked

            % Add Reset button
            uibutton(controlPanel, ...
                'Text', 'Reject', ...
                'Position', [400, 10, 70, 30], ...
                'ButtonPushedFcn', @(~, ~) uiresume(fig));
            uiwait(fig);

            % Close the figure
            close(fig);

            % Function to update intensity range dynamically
            function updatefig(hAxes, range)
                hAxes.CLim = range; % Adjust display range
            end


            % Function to reset ROI
            function confirm()
                state = hStack.SliceNumber; % Set the reset flag
                uiresume(fig); % Resume
            end
        end
    end
end

