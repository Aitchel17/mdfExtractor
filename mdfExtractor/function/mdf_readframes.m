function zstack = mdf_readframes(mobj, imgch, frames)
    % Read frames from an ActiveX-based .mdf file in batches.
    %
    % Inputs:
    %   mobj   - ActiveX object with ReadFrame method
    %   imgch  - Image channel to read
    %   frames - Vector of frame indices to read (compute outside this function)
    %
    % Output:
    %   zstack - H x W x numel(frames) image stack
    %
    % Example — read every 2nd frame from 100 to 500 on plane 1 of 3:
    %   frames = (100 : 3 : 500) + (1 - 1);   % plane2read=1, num_plane=3
    %   zstack = mdf_readframes(mobj, imgch, frames);

    % Parameters
    batchSize = 1000;
    verbose   = true;

    totalFrames = numel(frames);
    numBatches  = ceil(totalFrames / batchSize);

    % Pre-allocate cell array for batch results
    zstack = cell(1, numBatches);

    % Process each batch
    tic;
    for b = 1:numBatches
        fprintf('%.2f%% loaded\n', b * 100 / numBatches);
        batchIdx    = (b-1)*batchSize+1 : min(b*batchSize, totalFrames);
        zstack{b}   = io_readframes_simple(mobj, imgch, frames(batchIdx));
    end
    toc;

    % Combine batches
    if verbose
        fprintf('Combining batches into final Z-stack...\n');
    end
    zstack = cat(3, zstack{:});
end

function zstack = io_readframes_simple(mobj, imgch, indices)
    % Helper function to sequentially read frames
    % Inputs:
    %   mobj - ActiveX object
    %   imgch - Image channel
    %   indices - Indices of frames to read
    % Outputs:
    %   zstack - 3D image stack

    numFrames = numel(indices);

    % Read first frame to get dimensions
    sampleFrame = mobj.ReadFrame(imgch, indices(1))';
    [height, width] = size(sampleFrame);
    zstack = zeros(height, width, numFrames, 'like', sampleFrame);

    % Read each frame sequentially
    for idx = 1:numFrames
        frameIdx = indices(idx);
        zstack(:, :, idx) = mobj.ReadFrame(imgch, frameIdx)';
    end
end
