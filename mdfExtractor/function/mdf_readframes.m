function zstack = mdf_readframes(mobj, imgch, frames)
    % Read the given frames through a reused chunk buffer into a preallocated
    % output. Used to collect chunks in a cell and cat them; see CLAUDE_LOG.md
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

    n_frame = numel(frames);
    if n_frame == 0
        zstack = [];
        return;
    end
    chunk_frames = min(1000, n_frame); % frames per buffer fill (count)

    % probe the first frame for size and class, then allocate once
    sampleFrame = mobj.ReadFrame(imgch, frames(1))';
    [height, width] = size(sampleFrame);
    zstack = zeros(height, width, n_frame, 'like', sampleFrame);
    chunk  = zeros(height, width, chunk_frames, 'like', sampleFrame);

    n_chunk = ceil(n_frame / chunk_frames);
    for c = 1:n_chunk
        frame_idx = (c-1)*chunk_frames + 1 : min(c*chunk_frames, n_frame);
        n_held    = numel(frame_idx);
        for k = 1:n_held
            chunk(:, :, k) = mobj.ReadFrame(imgch, frames(frame_idx(k)))';
        end
        zstack(:, :, frame_idx) = chunk(:, :, 1:n_held);
        fprintf('%.2f%% loaded\n', frame_idx(end) * 100 / n_frame);
    end
end
