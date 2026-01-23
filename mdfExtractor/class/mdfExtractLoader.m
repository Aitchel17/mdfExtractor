classdef mdfExtractLoader
    % ANALYZE Summary of this class goes here
    %   Detailed explanation goes here
    properties
        info
        dir_struct = struct()
    end


    methods
        function obj = mdfExtractLoader(extract_dir)
            % Initialize info struct
            info = struct();

            if nargin == 0
                info.analyzefolder = uigetdir;
            elseif nargin == 1
                info.analyzefolder = extract_dir;
            end

            % Initialize dir_struct
            obj.dir_struct = struct();

            % Populate dir_struct
            obj.dir_struct.info = obj.get_filepath(info.analyzefolder, '*_info.txt');
            obj.dir_struct.analog = obj.get_filepath(info.analyzefolder, '*_analog.txt');
            obj.dir_struct.motion = obj.get_filepath(info.analyzefolder, '*_motion.txt');
            obj.dir_struct.ch1 = obj.get_filepath(info.analyzefolder, '*ch1.tif');
            obj.dir_struct.ch2 = obj.get_filepath(info.analyzefolder, '*ch2.tif');
            obj.dir_struct.eye = obj.get_filepath(info.analyzefolder, '*eye.avi');
            obj.dir_struct.whisker = obj.get_filepath(info.analyzefolder, '*whisker.avi');
            % Add other potential paths as needed (e.g. ch1.tif, ch2.tif can be handled similarly if consistent)

            % Load Info Table using the found path
            if ~isempty(obj.dir_struct.info)
                [~, info.infoname, ~] = fileparts(obj.dir_struct.info);
                info.infoname = [info.infoname '.txt']; % Reconstruct name if needed, or just store name separately

                tmp.info_table = readtable(obj.dir_struct.info);
                for i = 1:height(tmp.info_table)
                    info.(tmp.info_table.Field{i}) = tmp.info_table.Value{i};
                end
            else
                warning('Info file not found.');
            end

            obj.info = info;
        end

        function stack = loadstack(obj, channel)
            arguments
                obj
                channel (1,:) char {mustBeMember(channel, ["ch1","ch2"])}
            end

            disp('Loading')

            if isfield(obj.dir_struct, channel) && ~isempty(obj.dir_struct.(channel))
                fpath = obj.dir_struct.(channel);
            else
                error('Channel file path for %s not found in dir_struct.', channel);
            end



            stack = obj.analyze_readtiff(fpath);
        end

        function analog_info = loadanalog_info(obj)
            fprintf('Loading analog data from mdfExtracted folder')
            if isfield(obj.dir_struct, 'analog') && ~isempty(obj.dir_struct.analog)
                filename = obj.dir_struct.analog;
            else
                % Fallback or error
                error('Analog file path not found in dir_struct.');
            end

            % Open the file
            fileid = fopen(filename, 'r');
            if fileid == -1
                error('Could not open the file: %s', filename);
            end

            % Initialize output structs
            analog_info = struct();

            % Read header information
            section = 'header'; % Track which section we are in
            while ~feof(fileid)
                line = strtrim(fgetl(fileid)); % Read line and trim whitespace

                % Check for section headers
                if contains(line, '--- Analog Info')
                    section = 'header';
                    continue;
                elseif contains(line, '--- Analog Data')
                    section = 'data';
                    continue;
                end

                % Process header info
                if strcmp(section, 'header') && contains(line, ':')
                    tokens = split(line, ':'); % Split by colon
                    key = strtrim(tokens{1});
                    value = strtrim(tokens{2});
                    % Store in info struct
                    analog_info.(key) = value;
                end

                % Process data section
                if strcmp(section, 'data') && contains(line, ':')
                    break
                end
            end

            % Close the file
            fclose(fileid);
            fprintf('analog loading complete')
        end

        function analog_data = loadanalog_data(obj)
            fprintf('Loading analog data from mdfExtracted folder')
            if isfield(obj.dir_struct, 'analog') && ~isempty(obj.dir_struct.analog)
                filename = obj.dir_struct.analog;
            else
                % Fallback or error
                error('Analog file path not found in dir_struct.');
            end

            % Open the file
            fileid = fopen(filename, 'r');
            if fileid == -1
                error('Could not open the file: %s', filename);
            end

            % Initialize output structs
            analog_data = struct();

            % Read header information
            section = 'header'; % Track which section we are in
            while ~feof(fileid)
                line = strtrim(fgetl(fileid)); % Read line and trim whitespace

                % Check for section headers
                if contains(line, '--- Analog Info')
                    section = 'header';
                    continue;
                elseif contains(line, '--- Analog Data')
                    section = 'data';
                    continue;
                end

                % Process header info
                if strcmp(section, 'header') && contains(line, ':')
                    continue;
                end

                % Process data section
                if strcmp(section, 'data') && contains(line, ':')
                    tokens = split(line, ':'); % Split by colon
                    key = strtrim(tokens{1});
                    value = strtrim(tokens{2});
                    % Convert to numeric array
                    value = str2num(value); %#ok<ST2NM>
                    % Store in analog data struct
                    analog_data.(key) = value;
                end
            end

            % Close the file
            fclose(fileid);
            fprintf('analog loading complete')
        end

        function loadavi(obj)
            io_loadavi()
        end
        function motion = loadmotion(obj)
            fprintf('Loading global motion data from mdfExtracted folder')
            if isfield(obj.dir_struct, 'motion') && ~isempty(obj.dir_struct.motion)
                filename = obj.dir_struct.motion;
            else
                % Fallback or error
                error('Motion file path not found in dir_struct.');
            end

            % Open the file
            fileid = fopen(filename, 'r');
            if fileid == -1
                error('Could not open the file: %s', filename);
            end

            % Initialize output structs
            motion = struct();
            motion.fps = struct();
            motion.data = struct();

            % Read header information
            section = 'header'; % Track which section we are in
            while ~feof(fileid)
                line = strtrim(fgetl(fileid)); % Read line and trim whitespace

                % Check for section headers
                if contains(line, '--- Motion info')
                    section = 'header';
                    continue;
                elseif contains(line, '--- Motion table')
                    section = 'data';
                    continue;
                end

                % Process header info
                if strcmp(section, 'header') && contains(line, ':')
                    tokens = split(line, ':'); % Split by colon
                    key = strtrim(tokens{1});
                    value = strtrim(tokens{2});
                    % Store in info struct
                    motion.info.(key) = value;
                end

                % Process data section
                if strcmp(section, 'data') && contains(line, ':')
                    tokens = split(line, ':'); % Split by colon
                    key = strtrim(tokens{1});
                    value = strtrim(tokens{2});
                    % Convert to numeric array
                    value = str2num(value); %#ok<ST2NM>
                    % Store in analog data struct
                    motion.data.(key) = value;
                end
            end

            % Close the file
            fclose(fileid);
            fprintf('Global motion loading complete')
        end

    end


    methods (Access=private,Static)
        function channelData = analyze_readtiff(filePath)
            tic
            if ~isfile(filePath)
                fprintf('%s file not exist\n', filePath);
                channelData = [];
                return;
            end

            info = imfinfo(filePath);
            numFrames = numel(info);

            switch info(1).BitDepth
                case 16, dataClass = 'uint16';
                case 8, dataClass = 'uint8';
                otherwise, error('Unsupported BitDepth: %d', info(1).BitDepth);
            end

            % Preallocate data
            channelData = zeros(info(1).Height, info(1).Width, numFrames, dataClass);

            % Open file once
            tiffObj = Tiff(filePath, 'r');
            cleanup = onCleanup(@() tiffObj.close());

            [~, namingpattern, ~] = fileparts(filePath);
            h = waitbar(0, sprintf('Loading %s...', namingpattern));

            for idx = 1:numFrames
                setDirectory(tiffObj, idx);
                channelData(:,:,idx) = read(tiffObj);
                if mod(idx, 50) == 0 || idx == numFrames
                    waitbar(idx/numFrames, h);
                end
            end

            close(h);
            toc
        end

        function fpath = get_filepath(folder, pattern)
            filed_directory = dir(fullfile(folder, pattern));
            if length(filed_directory) == 1
                fpath = fullfile(filed_directory.folder, filed_directory.name);
            else
                warning('File pattern %s found %d times in %s. Using empty.', pattern, length(filed_directory), folder);
                fpath = '';
            end
        end


    end

end



