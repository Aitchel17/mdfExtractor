classdef mdfExtractLoader
    % ANALYZE Summary of this class goes here
    %   Detailed explanation goes here
    properties
        info
        analog
        stackch1
        stackch2
        roi
    end
    
    methods
        function obj = mdfExtractLoader(savepath)

        info = struct();
        info.analyzefolder = uigetdir;
        info.infoname = dir(fullfile(info.analyzefolder, '*_info.txt'));
        info.infoname = info.infoname.name;
        tmp.infopath = fullfile(info.analyzefolder, info.infoname);
        tmp.info_table = readtable(tmp.infopath);
        
        for i = 1:height(tmp.info_table)
            info.(tmp.info_table.Field{i}) = tmp.info_table.Value{i}; % Add the field and value to the struct
        end
        
        obj.info = info;
        obj.info.analysis_savepath = savepath;

        end
        % function analog = loadanalog(obj)
        % 
        % end


        function stack = loadstack(obj, channel)
            arguments
            obj
            channel (1,:) char {mustBeMember(channel, ["ch1","ch2"])}
            end

            disp('analyze class constructor activated')

            stack = obj.analyze_readtiff(obj.info.analyzefolder, ['*',channel,'.tif']);
        end
    
        function analog = loadanalog(obj)
            analogname = dir(fullfile(obj.info.analyzefolder,'*_analog.txt')).name;
            filename = fullfile(obj.info.analyzefolder,analogname);
            % Open the file
            fid = fopen(filename, 'r');
            if fid == -1
                error('Could not open the file.');
            end
        
            % Initialize output structs
            analog = struct();
            analog.info = struct();
            analog.data = struct();
            
            % Read header information
            section = 'header'; % Track which section we are in
            while ~feof(fid)
                line = strtrim(fgetl(fid)); % Read line and trim whitespace
                
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
            fclose(fid);
        end
    end
    methods (Access=private,Static)
        function channelData = analyze_readtiff(folderdirectory,namingpattern)
            tic
            % find .tif file
                channelDir = dir(fullfile(folderdirectory, namingpattern));
                if length(channelDir) ~= 1
                    fprintf('%s file not exist or plural num: %d\n', namingpattern, length(channelDir));
                    channelData = [];
                    return;
                end
               
                filePath = fullfile(folderdirectory, channelDir.name);
                
            % load metadata info    
                info = imfinfo(filePath);
                numFrames = numel(info);
            
                % Determine data type
                dataType = info(1).BitDepth;
                if dataType == 16
                    dataClass = 'uint16';
                elseif dataType == 8
                    dataClass = 'uint8';
                else
                    error('Unsupported BitDepth: %d', dataType);
                end
            
            % Loading 
                % Preallocate the array
                channelData = zeros(info(1).Height, info(1).Width, numFrames, dataClass);
            
                % Progress bar update rule
                updateInterval = max(1, round(numFrames / 100)); 
                D = parallel.pool.DataQueue;
                progress = 0;
                h = waitbar(0, sprintf('Loading %s...', namingpattern));
                afterEach(D, @(~) updateWaitbar());
            
                % parallel loading
                parfor idx = 1:numFrames
                    tempTiff = Tiff(filePath, 'r');
                    cleanup = onCleanup(@() tempTiff.close());         % object that trigger .close() when it destroied
                    tempTiff.setDirectory(idx);
                    channelData(:, :, idx) = tempTiff.read();
                    if mod(idx, updateInterval) == 0
                        send(D, idx);
                    end
                end
                close(h);
            
                function updateWaitbar()
                    progress = progress + updateInterval;
                    waitbar(min(progress / numFrames, 1), h);
                end
            toc
        end
    end
end



