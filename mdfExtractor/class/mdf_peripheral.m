classdef mdf_peripheral < mdf
    %MDF_PERIPHERAL  The other streams of one .mdf: the analog channels and the behavior camera
    %   Built from the same path as the 2P object, beside it. Never calls init, never reads a frame.

    properties
        analog                      % struct        .data and .info, what loadanalog read
        behavior                    % struct        size, count, rate and the two ROIs, from loadbehavior
        behavior_enable = 0         % 1 x 1 double  Video Enabled as the .mdf says; the script hands it to _info.txt
    end

    methods
        function obj = mdf_peripheral(paths)
            arguments
                paths = [];
            end
            obj@mdf(paths);
            % the frame loop: the control and the two writers, held from openavi to closeavi
            obj.state.mobj = [];
            obj.state.eye = [];
            obj.state.whisker = [];
        end

        function analog = loadanalog(obj)
            %LOADANALOG  the analog channels and their header off the .mdf
            mobj = obj.openmdf();
            [analog.data, analog.info] = mdf_readanalog(mobj);
            delete(mobj);
        end

        function saveanalog(obj)
            %SAVEANALOG  obj.analog as <name>_analog.txt
            analog_path = fullfile(obj.state.save_folder, [obj.info.mdfName(1:end-4), '_analog.txt']);
            io_1d2txt(analog_path, '--- Analog Info ---', obj.analog.info, ...
                [newline '--- Analog Data ---'], obj.analog.data);
        end

        function obj = loadbehavior(obj)
            %LOADBEHAVIOR  Video Enabled off the .mdf; if on, the camera's size, count, rate, two ROIs
            mobj = obj.openmdf();
            if strcmp(mobj.ReadParameter('Video Enabled'), '-1')
                disp('Behavior camera enable = -1 , loading behavior data')
                obj.behavior = mdf_peripheral.behaviorinfo(mobj);
                obj.behavior_enable = 1;
            else
                disp('Behavior camera enable = 0 , check .mdf file')
                obj.behavior_enable = 0;
            end
            delete(mobj);
        end

        function obj = openavi(obj)
            %OPENAVI  the control and the two writers the frame loop needs, held until closeavi
            obj.state.mobj = obj.openmdf();
            obj.state.eye = VideoWriter(fullfile(obj.state.save_folder, 'eye.avi'), 'Motion JPEG AVI');
            obj.state.eye.FrameRate = 33;
            obj.state.eye.Quality = 95;         % 0~100, lower is smaller
            obj.state.whisker = VideoWriter(fullfile(obj.state.save_folder, 'whisker.avi'), 'Motion JPEG AVI');
            obj.state.whisker.FrameRate = 33;
            obj.state.whisker.Quality = 80;
            open(obj.state.eye);
            open(obj.state.whisker);
        end

        function frame = loadbehaviorframe(obj, idx)
            %LOADBEHAVIORFRAME  one camera frame on the held control
            %
            % IN   idx    1 x 1 double   1-based, up to behavior.fcount
            % OUT  frame  H x W uint8
            frame = uint8(mod(double(obj.state.mobj.ReadVideoFrame(idx)'), 256));
        end

        function saveeye(obj, frame)
            %SAVEEYE  the eye ROI, smoothed and stretched, onto the eye writer
            vertex = obj.behavior.eyevertices;
            eyeframe = frame(vertex(1,2):vertex(3,2), vertex(1,1):vertex(3,1));
            eyeframe = imgaussfilt(eyeframe, 1);
            high = double(prctile(eyeframe(:), 99)) / 255;   % the brightest 1% clipped
            writeVideo(obj.state.eye, imadjust(eyeframe, [0, high], [0 1]));
        end

        function savewhisker(obj, frame)
            %SAVEWHISKER  the whisker ROI as read, onto the whisker writer
            vertex = obj.behavior.whiskervertices;
            writeVideo(obj.state.whisker, frame(vertex(1,2):vertex(3,2), vertex(1,1):vertex(3,1)));
        end

        function obj = closeavi(obj)
            %CLOSEAVI  what openavi held
            close(obj.state.eye);
            close(obj.state.whisker);
            delete(obj.state.mobj);
            obj.state.eye = [];
            obj.state.whisker = [];
            obj.state.mobj = [];
        end
    end

    methods (Access=protected, Static)
        function behavior = behaviorinfo(mobj)
            %BEHAVIORINFO  the camera's parameters, then the eye and whisker ROIs drawn on a demo stack
            behavior.fwidth  = mobj.ReadParameter('Video Width');
            behavior.fheight = mobj.ReadParameter('Video Height');
            if strcmp(mobj.ReadParameter('Video Mode'),'0')
                behavior.videomode = 'mono_8bit';
            else
                behavior.videomode = mobj.ReadParameter('Video Mode');
            end
            behavior.fcount = util_unit2double(mobj.ReadParameter('Video Image Count'));   % double, the loop bound
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
    end
end
