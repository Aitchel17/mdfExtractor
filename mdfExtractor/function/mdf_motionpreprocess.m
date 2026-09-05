function stack = mdf_motionpreprocess(stack, medfilt, clahe, clahe_size, wiener)
%MDF_MOTIONPREPROCESS  medfilt3 - normalize - clahe - wiener low-pass, frame by frame
%   Caller: mdf_xymovie.getdrifttable, mdf_xymovie.demoprepare
%
% IN   stack       H x W x T numeric
%      medfilt     1 x 3 double px  medfilt3 window [xy xy z]
%      clahe       1 x 1 logical
%      clahe_size  1 x 1 double px  CLAHE tile side
%      wiener      1 x 1 logical    wiener2 AND the low-pass after it
% OUT  stack       same size; 0~1 double once clahe or wiener ran,
%                  otherwise the class it came in as
    stack = medfilt3(stack, medfilt);
    if ~clahe && ~wiener
        return
    end
    wiener_size = 3;                    % px; the low-pass sigma is half of it
    out = zeros(size(stack));
    for frame_idx = 1:size(stack, 3)
        frame   = double(stack(:,:,frame_idx));
        min_val = min(frame,[],'all');
        max_val = max(frame,[],'all');
        frame   = (frame - min_val) / (max_val - min_val);
        if clahe
            n_tiles = max(2, round([size(frame,1), size(frame,2)] / clahe_size));
            frame = adapthisteq(frame, 'NumTiles', n_tiles, 'ClipLimit', 0.01, ...
                'NBins', 256, 'Range', 'full', 'Distribution', 'uniform');
        end
        if wiener
            frame = wiener2(frame, [wiener_size wiener_size]);
            lowpass = fspecial('gaussian', wiener_size, wiener_size/2);
            frame = imfilter(frame, lowpass, 'replicate');
        end
        out(:,:,frame_idx) = frame;
    end
    stack = out;
end
