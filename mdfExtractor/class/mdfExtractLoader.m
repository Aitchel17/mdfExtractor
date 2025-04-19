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
        function obj = mdfExtractLoader()

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
            analogfname = dir(fullfile(obj.info.analyzefolder,'*_analog.txt')).name;
            filename = fullfile(obj.info.analyzefolder,analogfname);
            % Open the file
            fileid = fopen(filename, 'r');
            if fileid == -1
                error('Could not open the file.');
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
            analog.data.t = linspace(0,str2double(analog.info.analogcount)/str2double(analog.info.analogfreq(1:end-3)),str2double(analog.info.analogcount));

        end

        function motion = loadmotion(obj)
            
            motionfname = dir(fullfile(obj.info.analyzefolder,'*_motion.txt')).name;
            filename = fullfile(obj.info.analyzefolder,motionfname);

            % Open the file
            fileid = fopen(filename, 'r');
            if fileid == -1
                error('Could not open the file.');
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
        end
        function air_puff_table = air_puff_extract(obj,airpuff_fieldname)
            binary_airpuff = obj.analog.data.(airpuff_fieldname)>0; % binarize data on or off
            diff_airpuff = diff(binary_airpuff); % differentiate rising and faling
            stim_on_idx = find(diff_airpuff ==1); % find rising edge, each data point is cumulative point when stim on
            stim_off_idx = find(diff_airpuff ==-1); % find falling edge
            stim_on_time = obj.analog.data.t(stim_on_idx); % match time scale, each data point is time when stim on
            stim_off_time = obj.analog.data.t(stim_off_idx+1);
            stim_on_int = diff(stim_on_time); % slope of stim on time point = frequency of stim
            session_boundary_idx = find(stim_on_int>10);
            session_end = [stim_off_time(session_boundary_idx),stim_off_time(end)];
            session_start = [stim_on_time(1),stim_on_time(session_boundary_idx+1)];
            session_duration = session_end-session_start;
            stim_on_off_idx = stim_off_idx-stim_on_idx;
            stim_on_on_idx = stim_on_idx(2:end)-stim_on_idx(1:end-1);
            stim_duty = stim_on_off_idx(1:end-1)./stim_on_on_idx;
            session_frequency = [];
            session_duty = [];
            for session_id = 0:length(session_boundary_idx)
            % initial
                if session_id == 0
                    session_start_idx = 1;
                    session_end_idx = session_boundary_idx(1)-1;
                elseif session_id == length(session_boundary_idx)
                    session_start_idx = session_boundary_idx(session_id)+1;
                    session_end_idx = length(stim_on_int);
                else
                    session_start_idx = session_boundary_idx(session_id)+1;
                    session_end_idx = session_boundary_idx(session_id+1)-1;
                end
                disp([session_start_idx,session_end_idx])
                session_frequency = [session_frequency,1/mean(stim_on_int(session_start_idx:session_end_idx))];
                session_duty = [session_duty,mean(stim_duty(session_start_idx:session_end_idx))];
            end
            air_puff_data = [session_start;session_end;session_duration;session_frequency;session_duty]';
            air_puff_table = array2table(air_puff_data,'VariableNames', {'StartTime', 'EndTime', 'Duration', 'FrequencyHz', 'DutyCycle'});
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



