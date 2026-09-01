function io_savetiff_frame(tiff_handle, tagstruct, frame, is_last)
%IO_SAVETIFF_FRAME  One frame into an open BigTIFF.
%   The rescale is a fixed affine map with no global statistic in it, which is what
%   lets it run per frame and give the same file a whole-stack rescale would.
%
% IN   tiff_handle  1 x 1 Tiff     from io_savetiff_open
%      tagstruct    1 x 1 struct   from io_savetiff_open, unchanged
%      frame        H x W numeric  one frame
%      is_last      1 x 1 logical  true suppresses the trailing directory
    if ~isa(frame, 'uint16')
        % ReadFrame gives signed 12-bit, so +2048 makes it unsigned and 4 bits of
        % the container are left over -- 16 steps per count, which is what carries
        % the fraction a groupz-frame mean has. Lossless while groupz <= 16.
        % Nothing is floored: a mean of signed 12-bit cannot leave [-2048, 2048]
        frame = double(frame);
        frame = (frame + 2048) / 4096 * 65535;
        frame = uint16(frame);
    end

    tiff_handle.setTag(tagstruct);
    tiff_handle.write(frame);
    if ~is_last
        tiff_handle.writeDirectory();
    end
end
