function [pixelShift_table] = pre_estimatemotion(stack,reference_img,Vertices)
    disp('Estimate motion to get drift table');
    xy = round(Vertices);

    % Extract the selected region from the stack
    stack = stack(xy(1,2):xy(3,2), xy(1,1):xy(3,1), :);
    % non negative
    stack = stack - min(stack,[],'all');
    % Display the selected region in a slice viewer
    figure(5);
    sliceViewer(stack);
    
    % Perform Fourier Transform on the first slice (used as reference)
    first_fft = fft2(reference_img(xy(1,2):xy(3,2), xy(1,1):xy(3,1), :));
    
    % Initialize the table to store pixel shifts
    pixelShift_table = zeros(4, size(stack, 3));  % 4 rows for shift values (x, y, and shifts)
    
    % Loop over all slices in the stack
    for sli = 1:size(stack, 3)
        
        
        % Fourier transform of the current slice
        regframe = fft2(stack(:,:,sli));
        
        % Estimate the pixel shift using DFT registration
        [pixelShift_table(:, sli), ~] = dft_registration(first_fft, regframe);
    end
    
    % Display the X and Y shifts
    figure('name', 'Pixel Shift', 'NumberTitle', 'off');
    subplot(2, 1, 1);
    xshift = medfilt1(pixelShift_table(4,:), 100);  % Apply median filter to smooth x-shifts
    plot(xshift);
    title('X shift');
    
    subplot(2, 1, 2);
    yshift = medfilt1(pixelShift_table(3,:), 100);  % Apply median filter to smooth y-shifts
    plot(yshift);
    title('Y shift');
end

