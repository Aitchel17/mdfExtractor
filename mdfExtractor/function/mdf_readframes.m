function zstack = mdf_readframes(mobj, imgch, zrange, num_plane, plane2read)
    % Function to read frames from ActiveX-based .mdf file in batches
    % Inputs:
    %   mobj - ActiveX object with ReadFrame method
    %   imgch - Image channel to read
    %   zrange - Range of frames [start, end]
    %   num_plane - (Optional) Number of planes to consider for subsampling
    %   plane2read - (Optional) Specific plane to read (1 to num_plane)
    % Output:
    %   zstack - 3D stack of frames

    % Hardcoded parameters
    batchSize = 1000; % Number of frames per batch
    verbose = true;   % Enable verbose output

    % Default values for num_plane and plane2read
    if nargin < 4 || isempty(num_plane)
        num_plane = 1; % Default to reading all frames
    end
    if nargin < 5 || isempty(plane2read)
        disp('select which plane to read')
    end

    % Compute the frame indices to read
    if num_plane > 1
        % Adjust indices based on num_plane and plane2read
        indices = zrange(1):num_plane:zrange(2);
        indices = indices + (plane2read - 1);
        % Ensure indices are within the specified range
        indices = indices(indices <= zrange(2));
    else
        indices = zrange(1):zrange(2);
    end

    totalFrames = numel(indices);
    numBatches = ceil(totalFrames / batchSize);

    % Pre-allocate zstack as a cell array to hold batch results
    zstack = cell(1, numBatches);

    % Process each batch
    tic;
    for b = 1:numBatches
        fprintf('%.2f%% loaded\n', b * 100 / numBatches);
        % Compute indices for the current batch
        batchStartIdx = (b - 1) * batchSize + 1;
        batchEndIdx = min(b * batchSize, totalFrames);
        batchIndices = indices(batchStartIdx:batchEndIdx);
        % Read the batch of frames
        zstack{b} = io_readframes_simple(mobj, imgch, batchIndices);
    end
    toc;

    % Combine batches into a single 3D stack
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
