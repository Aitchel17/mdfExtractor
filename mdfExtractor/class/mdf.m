classdef mdf
    %MDF  One .mdf as an object: info off MCSX, the read window as state, loadframes by chunk
    properties
        info
        stack                       % H x W x n      what loadframes read, then each stage's result
    end

    % loadstart / loadend / ch2read are the window a writer records and a script sets
    % with updatestate; the rest is what demoload and demomotion settled
    properties (SetAccess = protected)
        state = struct( ...
            'loadstart', 1,...
            'ch2read',  1 ...
            );
    end

    methods
        function obj = mdf(paths)
            %MDF  where the .mdf is and where its products go; init reads the rest
            arguments
                paths = [];
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
            % Saving folder path
            obj.state.save_folder = fullfile(obj.info.mdfPath, obj.info.mdfName(1:end-4));
            if ~exist(obj.state.save_folder, 'dir')
                mkdir(obj.state.save_folder);
            end
        end

        function obj = init(obj, objective, wavelength)
            %INIT  the 2P parameters off MCSX into info, and the read window they imply into state
            %   Caller: mdf_xymovie constructor, mdf_zstack constructor
            arguments
                obj
                objective = true;      % false discards the recorded objective and asks
                wavelength = 0;        % > 0 overrides the recorded excitation
            end
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
            obj.state.xpadstart = 1; % no left crop
            obj.state.xpadend = obj.info.fwidth; % no right crop
            obj.state.xshift = 0; % no pixel shift
            obj.state.groupz = 1; % no frame averaging
            % the read loop: where the read is, how long one read is, and the open writer
            obj.state.currentframe = obj.state.loadstart;
            obj.state.readlength = obj.info.fcount;   % one read is the whole recording until set
            obj.state.tiff = [];
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
                obj.info.objpix = obj.info.objpix/util_unit2double(obj.info.zoom);
            end
        end

        function obj = updatestate(obj, parameters)
            %UPDATESTATE  the window, the read length and the read position, as a script asks
            %   loadend is clamped to the recording; loadend and readlength are then trimmed to
            %   whole groupz blocks
            arguments
                obj
                parameters.loadstart    (1,1) {mustBeNumeric} = obj.state.loadstart
                parameters.loadend      (1,1) {mustBeNumeric} = obj.state.loadend
                parameters.ch2read      (1,1) {mustBeNumeric} = obj.state.ch2read
                parameters.readlength   (1,1) {mustBeNumeric} = obj.state.readlength
                parameters.currentframe (1,1) {mustBeNumeric} = obj.state.currentframe
            end
            obj.state.ch2read      = parameters.ch2read;
            obj.state.loadstart    = parameters.loadstart;
            obj.state.loadend      = parameters.loadend;
            obj.state.currentframe = parameters.currentframe;
            if obj.state.loadend > obj.info.fcount % beyond the last frame, read to the end
                disp('Duration exceed total frame, loadend set to the end')
                obj.state.loadend = obj.info.fcount;
            end
            if obj.state.loadstart < 1
                disp('frame start should above 1')
                obj.state.loadstart = 1;
            end
            n_group = floor((obj.state.loadend - obj.state.loadstart + 1) / obj.state.groupz);
            obj.state.loadend = obj.state.loadstart + n_group * obj.state.groupz - 1;
            n_readgroup = floor(parameters.readlength / obj.state.groupz);
            obj.state.readlength = n_readgroup * obj.state.groupz;
        end

        function obj = opentiff(obj)
            %OPENTIFF  the writer savetiff appends to, held until closetiff: <name>_ch<ch2read>.tif
            tif_path = fullfile(obj.state.save_folder, ...
                sprintf('%s_ch%d.tif', obj.info.mdfName(1:end-4), obj.state.ch2read));
            obj.state.tiff = Tiff(tif_path, 'w8');
        end

        function stack = loadframes(obj)
            %LOADFRAMES  the frames readwindow names: read - pad crop - pshift, on a control opened for it
            %
            % OUT  stack  H x W x n int16   margins cut, negatives kept
            [~, ~, read_start, read_stop] = obj.readwindow();
            mobj  = obj.openmdf();
            stack = mdf_readframes(mobj, obj.state.ch2read, read_start:read_stop);
            delete(mobj);
            stack = stack(:, obj.state.xpadstart:obj.state.xpadend, :);
            if obj.state.xshift ~= 0
                stack = mdf_pshiftcorrection(stack, obj.state.xshift);
            end
        end

        function savetiff(obj)
            %SAVETIFF  obj.stack onto the open writer, at the pages this read owns
            [own_start, ~, ~, ~] = obj.readwindow();
            n_page     = (obj.state.loadend - obj.state.loadstart + 1) / obj.state.groupz;
            first_page = (own_start - obj.state.loadstart) / obj.state.groupz + 1;
            n_own      = size(obj.stack, 3);
            tags = obj.label_tiftag(n_page, [size(obj.stack, 1), size(obj.stack, 2)]);
            for k = 1:n_own
                writepage(obj.state.tiff, tags, first_page + k - 1, ...
                    touint16(obj.stack(:, :, k)));
            end
            fprintf('%s ch%d: pages %d-%d of %d\n', obj.info.mdfName(1:end-4), ...
                obj.state.ch2read, first_page, first_page + n_own - 1, n_page);
        end

        function obj = closetiff(obj)
            %CLOSETIFF  the writer opentiff held
            obj.state.tiff.close();
            obj.state.tiff = [];
        end

        function info = state2info(obj)
            %STATE2INFO  the window and the page rate onto info, for saveinfo
            info = obj.info;
            info.loadstart = obj.state.loadstart;
            info.loadend   = obj.state.loadend;
            info.groupz    = obj.state.groupz;
            info.savefps   = obj.info.fps / obj.state.groupz;
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

        function [own_start, own_stop, read_start, read_stop] = readwindow(obj)
            %READWINDOW  the frames this read owns; here the load is the same span
            own_start  = obj.state.currentframe;
            own_stop   = min(own_start + obj.state.readlength - 1, obj.state.loadend);
            read_start = own_start;
            read_stop  = own_stop;
        end

        function tags = label_tiftag(obj, n_page, frame_size)
            %LABEL_TIFTAG  a page's tags: the xy scale off objpix, the page axis off the child's pageaxis
            %   Caller: mdf.savetiff
            %
            % IN   n_page      1 x 1 double   pages the file will hold
            %      frame_size  1 x 2 double   [height width] of one page
            % OUT  tags        1 x 1 struct   for Tiff.setTag
            [unit, page_keys, page_step] = obj.pageaxis();
            xy_step = util_unit2double(obj.info.objpix);       % um per pixel
            pixel_density = [10000 / xy_step, 10000 / xy_step];   % pixels per cm
            description = imagejblock(n_page, 1, unit, page_keys, page_step);
            tags = tiftag(description, pixel_density, Tiff.ResolutionUnit.Centimeter);
            tags.ImageLength = frame_size(1);
            tags.ImageWidth = frame_size(2);
            tags.RowsPerStrip = frame_size(1);
        end

        function [unit, page_keys, page_step] = pageaxis(obj) %#ok<STOUT>
            %PAGEAXIS  what one page step is: a child's answer (mdf_xymovie: time, mdf_zstack: depth)
            error('mdf:pageaxis', '%s has no page axis of its own; mdf_xymovie or mdf_zstack has', class(obj));
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

function description = imagejblock(n_frame, n_channel, unit, page_keys, page_step)
    %IMAGEJBLOCK  the ImageDescription lines ImageJ reads, as one char row
    %
    % IN   n_frame      1 x 1 double   pages along the page axis
    %      n_channel    1 x 1 double   channels
    %      unit         1 x 3 string   the unit of x, y and the page axis
    %      page_keys    1 x 2 string   what ImageJ calls the page count and the page
    %                                  step: ["slices" "spacing"] for a depth axis,
    %                                  ["frames" "finterval"] for a time axis
    %      page_step    1 x 1 double   one page in unit(3)
    % OUT  description  1 x n char
    %
    %   Every line needs its own newline. The page axis is the one thing here a scan
    %   mode decides, and it arrives as page_keys rather than being guessed from unit.
    description = [sprintf('ImageJ=1.54f\n'), ...
                   sprintf('images=%d\n', n_frame * n_channel), ...
                   sprintf('channels=%d\n', n_channel), ...
                   sprintf('%s=%d\n', page_keys(1), n_frame), ...
                   sprintf('unit=%s\n', unit(1)), ...
                   sprintf('yunit=%s\n', unit(2)), ...
                   sprintf('zunit=%s\n', unit(3)), ...
                   sprintf('%s=%g\n', page_keys(2), page_step)];
end

function tags = tiftag(description, pixel_density, resolution_unit)
    %TIFTAG  every tag a page of these TIFFs carries but its own size
    %
    % IN   description      1 x n char     from imagejblock, or another file's
    %      pixel_density    1 x 2 double   pixels per resolution_unit, [x y]. TIFF
    %                                      stores the reciprocal of a pixel's size,
    %                                      so um per pixel arrives here as 10000/um
    %      resolution_unit  1 x 1          Tiff.ResolutionUnit.*, or the numeric code
    %                                      getTag hands back
    % OUT  tags             1 x 1 struct   for Tiff.setTag; the caller adds the size
    tags.ImageDescription = description;
    tags.Photometric = Tiff.Photometric.MinIsBlack;
    tags.BitsPerSample = 16;
    tags.SamplesPerPixel = 1;
    tags.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
    tags.Compression = Tiff.Compression.None;
    tags.ResolutionUnit = resolution_unit;
    tags.XResolution = pixel_density(1);
    tags.YResolution = pixel_density(2);
    tags.Software = 'MATLAB';
end

function writepage(handle, tags, page, frame)
    %WRITEPAGE  one page onto an open TIFF
    %
    % IN   handle  1 x 1 Tiff      open for writing
    %      tags    1 x 1 struct    set on every page, size included
    %      page    1 x 1 double    which page of the FILE this is, 1-based
    %      frame   H x W uint16
    %
    %   The directory goes in FRONT of every page but the first, so nothing needs to
    %   know how many pages are coming and the file ends without a trailing empty one.
    if page > 1
        handle.writeDirectory();
    end
    handle.setTag(tags);
    handle.write(frame);
end

function frame = touint16(frame)
    %TOUINT16  a frame as MCSX gives it, in the container a TIFF page takes
    %
    % IN   frame  H x W numeric   signed 12-bit, or a mean of it; uint16 passes through
    % OUT  frame  H x W uint16
    %
    %   +2048 makes signed 12-bit unsigned and 4 bits of the container are left over,
    %   which is what carries the fraction a groupz-frame mean has.
    if isa(frame, 'uint16')
        return
    end
    frame = double(frame);
    frame = (frame + 2048) / 4096 * 65535;
    frame = uint16(frame);
end
