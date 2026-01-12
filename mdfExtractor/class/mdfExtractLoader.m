classdef mdfExtractLoader
    % ANALYZE Summary of this class goes here
    %   Detailed explanation goes here
    properties
        info
        path_struct = struct()
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

            % Initialize path_struct
            obj.path_struct = struct();

            % Populate path_struct
            obj.path_struct.info = obj.get_filepath(info.analyzefolder, '*_info.txt');
            obj.path_struct.analog = obj.get_filepath(info.analyzefolder, '*_analog.txt');
            obj.path_struct.motion = obj.get_filepath(info.analyzefolder, '*_motion.txt');
            obj.path_struct.ch1 = obj.get_filepath(info.analyzefolder, '*ch1.tif');
            obj.path_struct.ch2 = obj.get_filepath(info.analyzefolder, '*ch2.tif');
            % Add other potential paths as needed (e.g. ch1.tif, ch2.tif can be handled similarly if consistent)

            % Load Info Table using the found path
            if ~isempty(obj.path_struct.info)
                [~, info.infoname, ~] = fileparts(obj.path_struct.info);
                info.infoname = [info.infoname '.txt']; % Reconstruct name if needed, or just store name separately

                tmp.info_table = readtable(obj.path_struct.info);
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

            if isfield(obj.path_struct, channel) && ~isempty(obj.path_struct.(channel))
                fpath = obj.path_struct.(channel);
            else
                error('Channel file path for %s not found in path_struct.', channel);
            end

            % We need to pass folder and pattern to analyze_readtiff, or update analyze_readtiff to take full path.
            % Looking at analyze_readtiff (private static), it takes (folderdirectory, namingpattern).
            % It does a dir() search inside. We should probably update it or just wrap it.
            % Ideally, analyze_readtiff should take the direct file path if we already have it.
            % However, to minimize changes to analyze_readtiff if it's complex, we can pass folder and EXACT name.

            [folder, name, ext] = fileparts(fpath);
            stack = obj.analyze_readtiff(folder, [name, ext]);
        end

        function analog = loadanalog(obj)
            fprintf('Loading analog data from mdfExtracted folder')
            if isfield(obj.path_struct, 'analog') && ~isempty(obj.path_struct.analog)
                filename = obj.path_struct.analog;
            else
                % Fallback or error
                error('Analog file path not found in path_struct.');
            end

            % Open the file
            fileid = fopen(filename, 'r');
            if fileid == -1
                error('Could not open the file: %s', filename);
            end

            % Initialize output structs
            analog = struct();
            analog.info = struct();
            analog.data = struct();

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
                    analog.info.(key) = value;
                end

                % Process data section
                if strcmp(section, 'data') && contains(line, ':')
                    tokens = split(line, ':'); % Split by colon
                    key = strtrim(tokens{1});
                    value = strtrim(tokens{2});
                    % Convert to numeric array
                    value = str2num(value); %#ok<ST2NM>
                    % Store in analog data struct
                    analog.data.(key) = value;
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
            if isfield(obj.path_struct, 'motion') && ~isempty(obj.path_struct.motion)
                filename = obj.path_struct.motion;
            else
                % Fallback or error
                error('Motion file path not found in path_struct.');
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
        function channelData = analyze_readtiff(folderdirectory, namingpattern)
            tic
            channelDir = dir(fullfile(folderdirectory, namingpattern));
            if length(channelDir) ~= 1
                fprintf('%s file not exist or plural num: %d\n', namingpattern, length(channelDir));
                channelData = [];
                return;
            end

            filePath = fullfile(folderdirectory, channelDir.name);
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
                warning('File pattern %s found %d times in %s. Using empty.', pattern, length(d), folder);
                fpath = '';
            end
        end

        function [frames, fps] = io_loadavi(avidirectory)
            %READ_AVI One-pass AVI loader with preallocation (Duration*FPS estimate).
            % saved
            %   Returns grayscale frames (HxWxN, uint8) and fps.
            %   Shows progress in 5% steps.

            [fpath, tag, ~] = fileparts(avidirectory);
            frames = [];
            fps    = NaN;

            if ~isfile(avidirectory)
                fprintf('%s.avi does not exist\n', tag);
                return;
            end

            try
                vr = VideoReader(avidirectory);
                fps = vr.FrameRate;
                % If mdfExtractor videowriter initialized and ends up with error, avi file might not contain the frames in it
                if ~hasFrame(vr)
                    warning('%s.avi has no frames.', tag);
                    return;
                end

                % Read first frame for total frame estimation for preallocation
                firstFrame = readFrame(vr);
                if ndims(firstFrame) == 3
                    firstFrame = firstFrame(:,:,1); % grayscale 강제
                end
                [H,W] = size(firstFrame);

                % Estimated total frame number
                nEst = max(1, floor(vr.Duration * vr.FrameRate));

                % Array preallocation using estimated dimension
                frames = zeros(H,W,nEst,'uint8');
                frames(:,:,1) = firstFrame;

                % Read frames, update waitbar every 5%
                k = 1;
                pctNext = 5;
                while hasFrame(vr)
                    k = k + 1;
                    f = readFrame(vr);
                    if ndims(f) == 3, f = f(:,:,1); end
                    if ~isa(f,'uint8'), f = im2uint8(f); end
                    if k > size(frames,3)   % overshoot 대비 확장
                        frames(:,:,end+1) = 0;
                    end
                    frames(:,:,k) = f;

                    % update waitbar
                    pct = floor((k / nEst) * 100);
                    if pct >= pctNext
                        fprintf('\r[%s] Progress: %3d%%', tag, min(pct,100));
                        pctNext = pctNext + 5;
                    end
                end

                fprintf('\r[%s] Done. %d frames @ %.3f fps\n', tag, k, fps);
            catch ME
                warning('Failed to read %s: %s', tag, ME.message);
                frames = [];
                fps    = NaN;
            end
        end
    end

end



