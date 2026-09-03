function [tiff_handle, tagstruct] = io_savetiff_open(save_path, frame_size, n_frame, n_channel, resolution, unit)
%IO_SAVETIFF_OPEN  Open a BigTIFF and settle everything that is fixed for the file.
%   The frame count and the frame size go into the header, so both have to be known
%   before the first frame is written. That is the whole reason a streaming writer
%   needs the crop decided up front, or deferred to a second pass over the TIFF.
%
% IN   save_path    1 x n char     where the TIFF goes
%      frame_size   1 x 2 double   [height width] of one frame
%      n_frame      1 x 1 double   frames along z
%      n_channel    1 x 1 double   channels; 1 for a 3-D stack
%      resolution   1 x 3 double   [x y z] step per pixel and per page
%      unit         1 x 3 string   the unit of each, e.g. ["um" "um" "sec"]; "pixel" / "frame" when nothing is known
% OUT  tiff_handle  1 x 1 Tiff     open for writing. The CALLER closes it
%      tagstruct    1 x 1 struct   handed back to io_savetiff_frame unchanged
%
%   Output is uint16 whatever goes in: io_savetiff_frame rescales anything else, and
%   uint8 was never reaching the file either because the rescale ran first
    tiff_handle = Tiff(save_path, 'w8');

    % ImageJ reads this block; every line needs its own newline. A page axis in um
    % is its z (slices, spacing); any other page axis is its time (frames, finterval)
    if strcmp(unit(3), "um")
        page_count = sprintf('slices=%d\n', n_frame);
        page_step = sprintf('spacing=%g\n', resolution(3));
    else
        page_count = sprintf('frames=%d\n', n_frame);
        page_step = sprintf('finterval=%g\n', resolution(3));
    end
    description = [sprintf('ImageJ=1.54f\n'), ...
                   sprintf('images=%d\n', n_frame * n_channel), ...
                   sprintf('channels=%d\n', n_channel), ...
                   page_count, ...
                   sprintf('unit=%s\n', unit(1)), ...
                   sprintf('yunit=%s\n', unit(2)), ...
                   sprintf('zunit=%s\n', unit(3)), ...
                   page_step];
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
    % um as pixels per cm, as mdfExtractor's files carry it; any other unit as pixels per unit under None, as io_postsavetiff does
    if strcmp(unit(1), "um")
        tagstruct.ResolutionUnit = Tiff.ResolutionUnit.Centimeter;
        tagstruct.XResolution = 10000 / resolution(1);
        tagstruct.YResolution = 10000 / resolution(2);
    else
        tagstruct.ResolutionUnit = Tiff.ResolutionUnit.None;
        tagstruct.XResolution = 1 / resolution(1);
        tagstruct.YResolution = 1 / resolution(2);
    end
    tagstruct.Software = 'MATLAB';
end
