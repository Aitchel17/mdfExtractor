classdef mdf
    %MDF Summary of this class goes here
    %   Detailed explanation goes here

    properties
        info
        stack
        mobj % auto
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
            %MDF Construct an instance of this class
            %   Detailed explanation goes here
            if isempty(paths)
                [obj.info, obj.mobj] = mdf_init();
            elseif ischar(paths) == 1
                [obj.info, obj.mobj] = mdf_init(paths);
            else
                disp(class(paths))
                disp("invalid path info")
            end
            %   Default img frame reading parameter from beginning to end
            obj.state.loadend = obj.info.fcount;
            %   Default saving folder path
            obj.state.save_folder = fullfile(obj.info.mdfPath, obj.info.mdfName(1:end-4));
            if ~objective
                obj.info.objname = '<Unknown Objective>';
            end
            if wavelength > 0
                obj.info.excitation = wavelength;
            end
            if strcmp(obj.info.objname , '<Unknown Objective>')
                disp('Objective information is missing')
                [obj.info.objname, obj.info.objpix] = mdf_objectiveselector();
                obj.info.objpix = obj.info.objpix/str2double(obj.info.zoom(1:end-1));
            end
            if ~exist(obj.state.save_folder, 'dir')
                mkdir(obj.state.save_folder);
            end
            obj.state.xpadstart = 1;
            obj.state.xpadend = obj.info.fwidth;
            obj.state.xshift = 0;
            obj.state.groupz = 1;
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

