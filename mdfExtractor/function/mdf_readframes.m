function zstack = mdf_readframes(mobj, imgch, frames)
    % Read the given frames into a preallocated stack, each frame into its slot.
    %
    % Inputs:
    %   mobj   - ActiveX object with ReadFrame method
    %   imgch  - Image channel to read
    %   frames - Vector of frame indices to read (compute outside this function)
    %
    % Output:
    %   zstack - H x W x numel(frames) image stack (native pixel class)
    %
    % Example — read every 2nd frame from 100 to 500 on plane 1 of 3:
    %   frames = (100 : 3 : 500) + (1 - 1);   % plane2read=1, num_plane=3
    %   zstack = mdf_readframes(mobj, imgch, frames);
    arguments
        mobj
        imgch  (1,1) {mustBeNumeric}
        frames (1,:) {mustBeNumeric}
    end

    n_frame = numel(frames);
    if n_frame == 0
        zstack = [];
        return;
    end

    % probe the first frame for size and class, then allocate once
    sampleFrame = mobj.ReadFrame(imgch, frames(1))';
    [height, width] = size(sampleFrame);
    zstack = zeros(height, width, n_frame, 'like', sampleFrame);
    zstack(:, :, 1) = sampleFrame;

    for idx = 2:n_frame
        zstack(:, :, idx) = mobj.ReadFrame(imgch, frames(idx))';
    end
end
