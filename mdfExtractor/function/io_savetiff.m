function io_savetiff(zstack, save_path, resolution)
    % Save a 3D or 4D array (zstack) as a multi-page TIFF file with ImageJ-compatible metadata.
    %
    % Input:
    %   - zstack: 3D or 4D matrix of the image stack to save
    %   - save_path: Path to save the TIFF file
    %   - resolution: Vector [x_res, y_res, z_res] specifying the resolution in microns

    % Extract resolution values
    x_res = resolution(1);
    y_res = resolution(2);
    z_res = resolution(3);

    % Determine if the input is a 4D stack
    is4D = ndims(zstack) == 4;

    % Initialize the TIFF file
    t = Tiff(save_path, 'w8');

    % Metadata string for ImageJ
    ImgJ_ver = sprintf('ImageJ=1.54f\n');
    num_img = sprintf('images=%d\n', size(zstack, 3) * (is4D * size(zstack, 4) + ~is4D));
    num_ch = sprintf('channels=%d\n', is4D * size(zstack, 4) + ~is4D);
    num_frames = sprintf('frames=%d\n', size(zstack, 3));
    unit = sprintf('unit=um\n');
    zunit = sprintf('zunit=sec\n');
    spacing = sprintf('spacing=%d\n', z_res);

    ImageDescription = [ImgJ_ver, num_img, num_ch, ...
                        num_frames, unit, zunit, spacing];
    disp(ImageDescription);


   % Rescale 3D stacks if not uint16
    if ~isa(zstack, 'uint16')
        zstack = double(zstack);
        zstack = (zstack - 32) / 2048 * 65535; % 12 bit,count some negative value, mscan shows -32 to 2048 rescale to 65535, more negative would be noise
        zstack = uint16(zstack); % 
    end

    % Loop through each slice (and channel for 4D stacks)
    for i = 1:size(zstack, 3)
        for c = 1:(is4D * size(zstack, 4) + ~is4D)
            % Extract the frame
            if is4D
                frame = zstack(:, :, i, c);
            else
                frame = zstack(:, :, i);
            end
            
            % Set tag structure
            tagstruct.ImageDescription = ImageDescription;
            tagstruct.ImageLength = size(zstack, 1);
            tagstruct.ImageWidth = size(zstack, 2);
            tagstruct.Photometric = Tiff.Photometric.MinIsBlack;
            tagstruct.BitsPerSample = isa(zstack, 'uint8') * 8 + isa(zstack, 'uint16') * 16;
            tagstruct.SamplesPerPixel = 1;
            tagstruct.RowsPerStrip = size(zstack, 1);
            tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
            tagstruct.Compression = Tiff.Compression.None;
            tagstruct.ResolutionUnit = Tiff.ResolutionUnit.Centimeter;
            tagstruct.XResolution = 10000 / (x_res); % Convert microns to cm
            tagstruct.YResolution = 10000 / (y_res); % Convert microns to cm
            tagstruct.Software = 'MATLAB';

            % Write the frame
            t.setTag(tagstruct);
            t.write(frame);

            % Append mode for subsequent slices
            if i < size(zstack, 3) || (is4D && c < size(zstack, 4))
                t.writeDirectory();
            end
        end
    end

    % Close the TIFF file
    t.close();

    % Notify user of the save location
    fprintf('Saved zstack with metadata to %s\n', save_path);
end
