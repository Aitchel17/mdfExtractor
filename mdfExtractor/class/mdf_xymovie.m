classdef mdf_xymovie < mdf
    %MDF_ Summary of this class goes here
    %   Detailed explanation goes here

    properties
        analog
        drifttable
        behavior
    end

    methods
        function obj = mdf_xymovie(paths)
            arguments
                paths = [];
            end
            obj@mdf(paths);   % initialize by parent          
            mobj = obj.openmdf();   % open mdf
            [obj.analog.data, obj.analog.info] = mdf_readanalog(mobj); % read analog
            delete(mobj); % close mdf
            % default reading  option
            obj.state.groupz = 10;
            obj.state.xpadstart = 1;
            obj.state.xpadend = obj.info.fwidth;
            obj.state.xshift = 0;
            obj.state.motion_medfilt = [3, 3, 5];   % 1 x 3, medfilt3 window [xy xy z]
            % the three below feed the drift estimate only; the shifts are applied
            % to the raw stack, so nothing filtered by them reaches a stored pixel
            obj.state.motion_clahe = false;
            obj.state.motion_clahe_size = 64;      % CLAHE tile side (px)
            obj.state.motion_wiener = false;       % wiener2 and the low-pass after it
            % save analog
            analogfilename = fullfile(obj.state.save_folder, [obj.info.mdfName(1:end-4),'_analog.txt']);
            mdf_xymovie.saveanalog(obj.analog,analogfilename)
        end

        function obj = loadbehavior(obj)
            mobj = obj.openmdf();
            if strcmp(mobj.ReadParameter('Video Enabled'),'-1')
                disp('Behavior camera enable = -1 , loading behavior data')
                obj.behavior = mdf_xymovie.behaviorinfo(mobj);
                obj.info.behavior_enable = 1;
            else
                disp('Behavior camera enable = 0 , check .mdf file')
                obj.info.behavior_enable = 0;
            end
            delete(mobj);
        end

        function savebehavior(obj)
            if obj.info.behavior_enable
                disp('saving behavior')
                mobj = obj.openmdf();
                v1 = VideoWriter(fullfile(obj.info.mdfPath, obj.info.mdfName(1:end-4), "eye.avi"),'Grayscale AVI');
                v1.FrameRate = 30.9;
                v2 = VideoWriter(fullfile(obj.info.mdfPath, obj.info.mdfName(1:end-4), "whisker.avi"),'Grayscale AVI');
                v2.FrameRate = 30.9;
                open(v1);
                open(v2);
                for idx = 1:str2double(obj.behavior.fcount)
                    frame = uint8(mod(double(mobj.ReadVideoFrame(idx)'),256));
                    writeVideo(v1,frame(obj.behavior.eyevertices(1,2):obj.behavior.eyevertices(3,2), obj.behavior.eyevertices(1,1):obj.behavior.eyevertices(3,1)))
                    writeVideo(v2,frame(obj.behavior.whiskervertices(1,2):obj.behavior.whiskervertices(3,2), obj.behavior.whiskervertices(1,1):obj.behavior.whiskervertices(3,1)))
                end
                delete(mobj);
                close(v1);
                close(v2);
                disp('behavior data saved')
            else
                disp('behavior disabled')
            end
        end
        
        function savecompbehavior(obj)
            if obj.info.behavior_enable
                disp('saving behavior')
                mobj = obj.openmdf();

                % 압축 가능한 Motion JPEG AVI로 변경
                v1 = VideoWriter(fullfile(obj.info.mdfPath, obj.info.mdfName(1:end-4), "eye.avi"), 'Motion JPEG AVI');
                v2 = VideoWriter(fullfile(obj.info.mdfPath, obj.info.mdfName(1:end-4), "whisker.avi"), 'Motion JPEG AVI');

                % 프레임 속도 및 압축 품질 설정
                v1.FrameRate = 33;
                v2.FrameRate = 33;
                v1.Quality = 95;  % 0~100 (낮을수록 더 압축됨)
                v2.Quality = 80;

                open(v1);
                open(v2);

                for idx = 1:str2double(obj.behavior.fcount)
                    % 프레임 읽기 및 범위 변환
                    frame = uint8(mod(double(mobj.ReadVideoFrame(idx)'), 256));

                    % ROI 추출
                    eyeframe = frame(...
                        obj.behavior.eyevertices(1,2):obj.behavior.eyevertices(3,2), ...
                        obj.behavior.eyevertices(1,1):obj.behavior.eyevertices(3,1));

                    whiskerframe = frame(...
                        obj.behavior.whiskervertices(1,2):obj.behavior.whiskervertices(3,2), ...
                        obj.behavior.whiskervertices(1,1):obj.behavior.whiskervertices(3,1));
                    % 1. 밝은 반사점 억제 + 명암도 확장 (clip 상위 1% 제거)
                    eyeframe = imgaussfilt(eyeframe,1);
                    high = double(prctile(eyeframe(:), 99)) / 255;  % 상위 0.5% 잘라내기

                    eyeframe_adj = imadjust(eyeframe, [0, high], [0 1]);


                    % 프레임 저장
                    writeVideo(v1, eyeframe_adj);
                    writeVideo(v2, whiskerframe);
                end
                delete(mobj);

                close(v1);
                close(v2);

                disp('behavior data saved')
            else
                disp('behavior disabled')
            end
        end

        function obj = updatestate(obj,parameters)
            %UPDATESTATE  Move the reading window. The chunk cursor, nothing else.
            %   What demoload and demomotion settled cannot be reached from here:
            %   changing groupz or a filter once motion_refimg exists would leave
            %   state describing a reference image it was not made with.
            arguments
                obj
                parameters.loadstart(1,1) {mustBeNumeric} = obj.state.loadstart
                parameters.loadend(1,1) {mustBeNumeric}   = obj.state.loadend
                parameters.ch2read (1,1) {mustBeNumeric}  = obj.state.ch2read
            end

            obj.state.ch2read   = parameters.ch2read;
            obj.state.loadstart = parameters.loadstart;
            obj.state.loadend   = parameters.loadend;

            if obj.state.loadend > obj.info.fcount % beyond the last frame, read to the end
                disp('Duration exceed total frame, loadend set to the end')
                obj.state.loadend = obj.info.fcount;
            end
            if obj.state.loadstart < 1
                disp('frame start should above 1')
                obj.state.loadstart = 1;
            end
        end

        function info = state2info(obj, fieldname)
            arguments
                obj
                fieldname.loadstart = true
                fieldname.loadend = true
                fieldname.xshift = true
                fieldname.motion_refframes = true
                fieldname.motion_refchannel = true
                fieldname.motion_vertices = true
                fieldname.groupz = true
                fieldname.motion_medfilt = true
                fieldname.motion_clahe = true
                fieldname.motion_clahe_size = true
                fieldname.motion_wiener = true
            end

            % Initialize info with the existing obj.info
            info = obj.info;

            % Get all field names from fieldname structure
            fields = fieldnames(fieldname);

            % Iterate over the field names and update info if the fieldname value is true
            for i = 1:numel(fields)
                field = fields{i}; % Get the current field name
                if fieldname.(field) % Check if the field is flagged as true
                    if strcmp(field, 'motion_vertices') % Special case for motion_vertices
                        info.(field) = strjoin(string(reshape(obj.state.motion_vertices', 1, [])));
                    elseif strcmp(field, 'motion_medfilt') % writetable needs a scalar or a string
                        info.(field) = strjoin(string(obj.state.motion_medfilt));
                    elseif strcmp(field, 'motion_refframes') % first and last acquisition frame
                        info.(field) = strjoin(string(obj.state.motion_refframes));
                    else
                        info.(field) = obj.state.(field); % General case
                    end
                end
            end
        end



        function [obj, demo] = demoload(obj, refimgchannel, option)
            %DEMOLOAD  Read the frames the demo runs on, and settle the line phase.
            %   The expensive half -- about 5% of the recording comes off the .mdf
            %   here. demo.raw is left unfiltered so demomotion can be run again
            %   with other settings without a second read.
            %
            % OUT  demo.raw     H x W x T int16   as read, margins still at -2048
            %      demo.frames  1 x T double      the acquisition frame of each
            arguments
                obj
                refimgchannel (1,1) {mustBeNumeric}
                option.groupz (1,1) {mustBeNumeric} = obj.state.groupz
            end

            obj.state.motion_refchannel = refimgchannel;
            obj.state.ch2read = refimgchannel;
            obj.state.groupz  = option.groupz;
            demo.frames = obj.demoframes(obj.state.loadstart, obj.state.groupz);
            mobj = obj.openmdf();
            demo.raw = mdf_readframes(mobj, obj.state.motion_refchannel, demo.frames);
            delete(mobj);   % the dialog below only needs the stack, not the file
            obj.state.xshift = mdf_pshiftexplorer(demo.raw);
        end

        function [obj, demo] = demomotion(obj, demo, option)
            %DEMOMOTION  Filter the demo stack and settle the drift reference.
            %   Seconds plus two dialogs, never a .mdf read, so it can be run again
            %   on the same demo to see one filter setting against another.
            %   demo.raw is not touched; the filtered copy is demo.processed.
            arguments
                obj
                demo
                option.motion_medfilt (1,3) {mustBeNumeric} = obj.state.motion_medfilt
                option.motion_clahe (1,1) logical = obj.state.motion_clahe
                option.motion_clahe_size (1,1) {mustBeNumeric} = obj.state.motion_clahe_size
                option.motion_wiener (1,1) logical = obj.state.motion_wiener
            end
            obj.state.motion_medfilt    = option.motion_medfilt;
            obj.state.motion_clahe      = option.motion_clahe;
            obj.state.motion_clahe_size = option.motion_clahe_size;
            obj.state.motion_wiener     = option.motion_wiener;

            [demo.processed, obj.state.xpadstart, obj.state.xpadend] = mdf_xymovie.demoprepare( ...
                demo.raw, obj.state.xshift, obj.state.groupz, obj.state.motion_medfilt, ...
                obj.state.motion_clahe, obj.state.motion_clahe_size, obj.state.motion_wiener);

            % demo.frames is the list demoload read, so the slice a person picks is
            % written down as the acquisition frames it averaged rather than as an
            % index into a stack that only exists inside this call
            qualitycontrol = false;
            while qualitycontrol == false
                [obj.state.motion_vertices, ref_slice] = mdf_rectangle_polygon(demo.processed, 'rectangle');
                block = (ref_slice - 1) * obj.state.groupz + 1 : ref_slice * obj.state.groupz;
                obj.state.motion_refframes = [demo.frames(block(1)), demo.frames(block(end))];   % 1 x 2 frame
                obj.state.motion_refimg = demo.processed(:,:,ref_slice);
                demo.drift_table = pre_estimatemotion(demo.processed, obj.state.motion_refimg, obj.state.motion_vertices);
                [demo.correctedstack, demo.ip_Drifttable] = pre_applymotion(demo.processed, demo.drift_table);
                qualitycontrol = mdf.checkstack(demo.correctedstack);
            end
        end

        function obj = restore(obj)
            %RESTORE  The demoload/demomotion state back from the _info.txt.
            info_path = fullfile(obj.state.save_folder, [obj.info.mdfName(1:end-4), '_info.txt']);
            saved     = fileread(info_path);

            state = obj.state;
            state.groupz       = str2double(infofield(saved, 'groupz'));
            % the four below entered state after most of the tree was extracted, so
            % an older _info.txt has no row for them; the default is what that
            % extraction actually ran with. Everything else must be in the file
            state.motion_medfilt = str2num(infofield(saved, 'motion_medfilt', '3 3 5')); %#ok<ST2NM> 1 x 3
            state.motion_refchannel   = str2double(infofield(saved, 'motion_refchannel'));
            state.ch2read      = state.motion_refchannel;
            state.motion_refframes    = str2num(infofield(saved, 'motion_refframes')); %#ok<ST2NM> 1 x 2
            state.xshift       = str2double(infofield(saved, 'xshift'));
            state.motion_clahe        = logical(str2double(infofield(saved, 'motion_clahe', '0')));
            state.motion_clahe_size   = str2double(infofield(saved, 'motion_clahe_size', '64'));
            state.motion_wiener       = logical(str2double(infofield(saved, 'motion_wiener', '0')));
            % state2info flattens the 4 x 2 by rows, so the inverse is 2 x 4 turned
            flat = str2num(infofield(saved, 'motion_vertices')); %#ok<ST2NM> 1 x 8
            state.motion_vertices = reshape(flat, 2, 4)';

            frames = obj.demoframes(1, state.groupz);
            at     = find(frames == state.motion_refframes(1), 1);
            if isempty(at) || mod(at - 1, state.groupz) ~= 0 || frames(at + state.groupz - 1) ~= state.motion_refframes(2)
                error('mdf_xymovie:restore', ...
                    'frame %d does not start a group of %d in the rebuilt demo list, so the reference cannot be located', ...
                    state.motion_refframes(1), state.groupz);
            end
            ref_slice = (at - 1) / state.groupz + 1;

            mobj = obj.openmdf();
            demo_stack = mdf_readframes(mobj, state.motion_refchannel, frames);
            delete(mobj);
            [demo_stack, state.xpadstart, state.xpadend] = mdf_xymovie.demoprepare( ...
                demo_stack, state.xshift, state.groupz, state.motion_medfilt, ...
                state.motion_clahe, state.motion_clahe_size, state.motion_wiener);
            state.motion_refimg = demo_stack(:, :, ref_slice);
            fprintf('restored from %s : xpad %d-%d, refimg %d x %d, reference frames %d-%d\n', ...
                info_path, state.xpadstart, state.xpadend, size(state.motion_refimg, 1), ...
                size(state.motion_refimg, 2), state.motion_refframes(1), state.motion_refframes(2));
            obj.state = state;
        end

        function estimated_drifttable = getdrifttable(obj)
            % Preprcocessing (Padding removal -> post pixel shift correction -> Trim -> Non Negative -> group average -> medfilt3)
            % group averaging
            disp('group averaging')
            zstack = pre_groupaverage(obj.stack, obj.state.groupz); % denoise by group averaging
            % median filter, state.motion_medfilt
            disp('3D median filtering')
            zstack = medfilt3(zstack,obj.state.motion_medfilt); % denoise by 3d median filter
            estimated_drifttable = pre_estimatemotion(zstack,obj.state.motion_refimg,obj.state.motion_vertices);
            % the whole table at once; pre_estimatemotion drew one per call
            figure('name', 'Pixel Shift', 'NumberTitle', 'off');
            subplot(2, 1, 1);
            plot(estimated_drifttable(4, :));
            title('X shift');
            subplot(2, 1, 2);
            plot(estimated_drifttable(3, :));
            title('Y shift');
            driftfilename = fullfile(obj.state.save_folder, [obj.info.mdfName(1:end-4),'_motion.txt']);
            mdf_xymovie.savemotion(estimated_drifttable,obj.info.fps/obj.state.groupz,driftfilename)
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


        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    end % end of method

    methods (Access=protected)
        function frames = demoframes(obj, loadstart, groupz)
            %DEMOFRAMES  ~5% of the recording, spread evenly, in groupz blocks.
            %   Spread so the reference is not taken from the beginning only.
            %   Each block is exactly groupz frames so pre_groupaverage gets
            %   complete, aligned groups -- which is what makes slice k of the
            %   demo stack the average of frames chunk_starts(k) .. +groupz-1.
            total_frames = obj.info.fcount - loadstart + 1;
            n_chunks     = max(5, round(total_frames * 0.05 / groupz));
            chunk_starts = unique(round(linspace(loadstart, ...
                               obj.info.fcount - groupz + 1, n_chunks)));
            frames = reshape((chunk_starts(:) + (0:groupz-1))', 1, []);
        end
    end

    methods (Access=protected, Static)
        function [stack, xpadstart, xpadend] = demoprepare(stack, xshift, groupz, medfilt_size, clahe, clahe_size, wiener)
            %DEMOPREPARE  The half of the demo that asks nothing.
            %   demomotion and restore both run it, so the refimg restore
            %   recomputes is the one demo would have produced.
            %   Negatives are kept, the same as loadframes -- refimg and the frames
            %   it is correlated against have to carry the same convention.
            %   findpadding runs first because it looks for the -2048 fill
            stack = mdf_pshiftcorrection(stack, xshift);
            [xpadstart, xpadend] = mdf.findpadding(stack);
            stack = pre_groupaverage(stack(:, xpadstart:xpadend, :), groupz);
            stack = medfilt3(stack, medfilt_size);
            stack = mdf_xymovie.preprocstack(stack, clahe, clahe_size, wiener);
        end

        function behavior = behaviorinfo(mobj)
            behavior.fwidth  = mobj.ReadParameter('Video Width');
            behavior.fheight = mobj.ReadParameter('Video Height');
            if strcmp(mobj.ReadParameter('Video Mode'),'0')
                behavior.videomode = 'mono_8bit';
            else
                behavior.videomode = mobj.ReadParameter('Video Mode');
            end
            behavior.fcount = mobj.ReadParameter('Video Image Count');
            behavior.frate = mobj.ReadParameter('Video Rate');
            behavior.democount = 2000;
            sampleFrame = mobj.ReadVideoFrame(1)';
            [height, width] = size(sampleFrame);
            demostack = zeros(height,width, behavior.democount);%, 'like', sampleFrame);
            for idx = 1:behavior.democount
                demostack(:,:,idx) = mobj.ReadVideoFrame(idx)';
            end
            demostack = mod(demostack,256);
            disp('select eye vertices')
            [behavior.eyevertices, ~] = mdf_rectangle_polygon(demostack,'rectangle');
            disp('select whisker and nose vertices')
            [behavior.whiskervertices, ~] = mdf_rectangle_polygon(demostack,'rectangle');
            figure("Name",'behavior demo')
            sliceViewer(demostack)
        end

        function saveanalog(analog, filename)
            analogdata = analog.data;
            analoginfo = analog.info;
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

    end % end of method

    methods (Static)
        function stack = preprocstack(stack, clahe, clahe_size, wiener)
            %PREPROCSTACK  CLAHE and the Wiener low-pass over a stack, frame by frame.
            %   demoprepare and mdf_streamextract both run it, so refimg and the
            %   frames it is correlated against carry the same convention. It only
            %   feeds the drift estimate -- the shifts are applied to the raw stack,
            %   so nothing filtered here ever reaches a stored pixel.
            %
            %   The WHOLE frame, not the motion box. CLAHE tiles whatever region it
            %   is handed, so a box and a frame disagree inside the box; a local
            %   median filter does not, which is why medfilt3 may run on the box.
            %
            %   adapthisteq needs 0~1 and the scale is the signed 12-bit range,
            %   fixed. A per-frame min and max would make one chunk's normalisation
            %   depend on that chunk's content. PIVlab's other stages are pinned
            %   off: imadjust neutral at 0 and 1, no high-pass, no intensity cap.
            %
            % IN   stack       H x W x T numeric
            %      clahe       1 x 1 logical
            %      clahe_size  1 x 1 double px   CLAHE tile side
            %      wiener      1 x 1 logical     wiener2 AND the low-pass after it
            % OUT  stack       same size, 0~1 double when either filter ran
            if ~clahe && ~wiener
                return
            end
            out = zeros(size(stack));
            for frame_idx = 1:size(stack, 3)
                scaled = (double(stack(:,:,frame_idx)) + 2048) / 4096;
                out(:,:,frame_idx) = mdf_preprocframe(scaled, [], ...
                    clahe, clahe_size, false, 15, false, wiener, 3, 0, 1);
            end
            stack = out;
        end

        function savemotion(motiontable,motionfps,filename)
            % public: a chunked caller builds the table over several loads and
            % writes it once, so the write cannot sit inside getdrifttable
            % dft_registration's four rows, in its order. They were written as
            % yerror / xerror / ymotion / xmotion, which put an axis on the two
            % that have none and said y,x for what are row,col -- the same
            % confusion that cut every TIFF with the axes crossed until 2026-08-29
            regerror  = mat2str(motiontable(1,:));   % sqrt(1 - |CCmax|^2/(E1*E2)), 0 = identical
            diffphase = mat2str(motiontable(2,:));   % angle(CCmax), 0 for real images
            rowshift  = mat2str(motiontable(3,:));   % the correction, not the tissue's motion
            colshift  = mat2str(motiontable(4,:));

            fileID = fopen(filename,'w');
            fprintf(fileID, '--- Motion info ---\n');
            fprintf(fileID, 'driftestimation_fps: %s\n', num2str(motionfps));
            fprintf(fileID, '--- Motion table ---\n');
            fprintf(fileID, '%s: %s\n', 'regerror', regerror);
            fprintf(fileID, '%s: %s\n', 'diffphase', diffphase);
            fprintf(fileID, '%s: %s\n', 'rowshift', rowshift);
            fprintf(fileID, '%s: %s\n', 'colshift', colshift);
            fclose(fileID);

        end
    end
end

function value = infofield(saved, key, default)
%INFOFIELD  One Field,Value row out of the text saveinfo wrote.
%   readtable turns the row this needs into <missing>, so the file is read as
%   text. The Comments field is quoted and spans lines, hence the anchors.
%
% IN   saved    1 x n char     the whole file
%      key      1 x n char     the Field to return
%      default  1 x n char     what an absent key means, as text the caller
%                              converts the same way; omit to make absence an
%                              error, which is right for anything measured
% OUT  value    1 x n char
    hit = regexp(saved, ['^', key, ',(.*)'], 'tokens', 'once', ...
        'lineanchors', 'dotexceptnewline');
    if isempty(hit)
        if nargin >= 3
            value = default;
            return
        end
        error('mdf_xymovie:infofield', '%s carries no %s', 'the info file', key);
    end
    value = strtrim(hit{1});
end
