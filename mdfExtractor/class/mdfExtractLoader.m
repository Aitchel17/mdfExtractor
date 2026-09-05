classdef mdfExtractLoader
    %MDFEXTRACTLOADER  One extraction folder: its _info.txt as a struct, its file paths, loadstack
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

            % Load Info Table using the found path
            if ~isempty(obj.dir_struct.info)
                [~, info.infoname, ~] = fileparts(obj.dir_struct.info);
                info.infoname = [info.infoname '.txt'];   % the file name, extension back on

                saved = io_loadinfo(obj.dir_struct.info);
                info = util_mergestruct(info, saved);
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

            stack = obj.readtiff(fpath);
        end

        function analog_info = loadanalog_info(obj)
            %LOADANALOG_INFO  the header of _analog.txt, every value as written
            if isfield(obj.dir_struct, 'analog') && ~isempty(obj.dir_struct.analog)
                filename = obj.dir_struct.analog;
            else
                error('Analog file path not found in dir_struct.');
            end
            [analog_info, ~] = io_txt21d(filename);
        end

        function analog_data = loadanalog_data(obj)
            %LOADANALOG_DATA  the channels of _analog.txt, one 1 x N row each
            if isfield(obj.dir_struct, 'analog') && ~isempty(obj.dir_struct.analog)
                filename = obj.dir_struct.analog;
            else
                error('Analog file path not found in dir_struct.');
            end
            [~, analog_data] = io_txt21d(filename);
        end

        function loadavi(obj)
            io_loadavi()
        end
        function motion = loadmotion(obj)
            %LOADMOTION  _motion.txt: .info the header as written, .data dft_registration's four rows
            if isfield(obj.dir_struct, 'motion') && ~isempty(obj.dir_struct.motion)
                filename = obj.dir_struct.motion;
            else
                error('Motion file path not found in dir_struct.');
            end
            motion.fps = struct();
            [motion.info, motion.data] = io_txt21d(filename);
        end

    end

    methods (Access=private,Static)
        function channelData = readtiff(filePath)
            %READTIFF  one extracted TIFF, whole, in the class it was written as
            %   Caller: mdfExtractLoader.loadstack
            %
            % IN   filePath     1 x n char        the TIFF; [] back if it is not there
            % OUT  channelData  H x W x N uint16  every page
            %
            %   No tag is read but BitDepth: this class takes its metadata from the
            %   _info.txt beside the stack, so a TIFF tag has nothing to add.
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

