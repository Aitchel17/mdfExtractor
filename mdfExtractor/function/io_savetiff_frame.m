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
        % 12 bit, count some negative value, mscan shows -32 to 2048 rescale to
        % 65535, more negative would be noise
        frame = double(frame);
        frame = (frame - 32) / 2048 * 65535;
        frame = uint16(frame);
    end

    tiff_handle.setTag(tagstruct);
    tiff_handle.write(frame);
    if ~is_last
        tiff_handle.writeDirectory();
    end
end
