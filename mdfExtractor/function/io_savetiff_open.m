function [tiff_handle, tagstruct] = io_savetiff_open(save_path, frame_size, n_frame, n_channel, resolution)
%IO_SAVETIFF_OPEN  Open a BigTIFF and settle everything that is fixed for the file.
%   The frame count and the frame size go into the header, so both have to be known
%   before the first frame is written. That is the whole reason a streaming writer
%   needs the crop decided up front, or deferred to a second pass over the TIFF.
%
% IN   save_path    1 x 1 char     where the TIFF goes
%      frame_size   1 x 2 double   [height width] of one frame
%      n_frame      1 x 1 double   frames along z
%      n_channel    1 x 1 double   channels; 1 for a 3-D stack
%      resolution   1 x 3 double   [x_res y_res z_res], microns and seconds
% OUT  tiff_handle  1 x 1 Tiff     open for writing. The CALLER closes it
%      tagstruct    1 x 1 struct   handed back to io_savetiff_frame unchanged
%
%   Output is uint16 whatever goes in: io_savetiff_frame rescales anything else, and
%   uint8 was never reaching the file either because the rescale ran first
    tiff_handle = Tiff(save_path, 'w8');

    % ImageJ reads this block; every line needs its own newline
    description = [sprintf('ImageJ=1.54f\n'), ...
                   sprintf('images=%d\n', n_frame * n_channel), ...
                   sprintf('channels=%d\n', n_channel), ...
                   sprintf('frames=%d\n', n_frame), ...
                   sprintf('unit=um\n'), ...
                   sprintf('zunit=sec\n'), ...
                   sprintf('spacing=%d\n', resolution(3))];
    disp(description);

    tagstruct.ImageDescription = description;
    tagstruct.ImageLength = frame_size(1);
    tagstruct.ImageWidth = frame_size(2);
    tagstruct.Photometric = Tiff.Photometric.MinIsBlack;
    tagstruct.BitsPerSample = 16;
    tagstruct.SamplesPerPixel = 1;
    tagstruct.RowsPerStrip = frame_size(1);
    tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
    tagstruct.Compression = Tiff.Compression.None;
    tagstruct.ResolutionUnit = Tiff.ResolutionUnit.Centimeter;
    tagstruct.XResolution = 10000 / resolution(1);   % microns to cm
    tagstruct.YResolution = 10000 / resolution(2);
    tagstruct.Software = 'MATLAB';
end
