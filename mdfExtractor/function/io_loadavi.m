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

