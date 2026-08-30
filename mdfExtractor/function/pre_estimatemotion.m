function [pixelShift_table] = pre_estimatemotion(stack,reference_img,Vertices,pairwise)
arguments
    stack
    reference_img
    Vertices
    pairwise = false
end

    disp('Estimate motion to get drift table');
    xy = round(Vertices);

    % Extract the selected region from the stack
    stack = stack(xy(1,2):xy(3,2), xy(1,1):xy(3,1), :);

    % Initialize the table to store pixel shifts
    pixelShift_table = zeros(4, size(stack, 3));  % 4 rows for shift values (x, y, and shifts)
    
    
    % Perform Fourier Transform on the first slice (used as reference)
    first_fft = fft2(reference_img(xy(1,2):xy(3,2), xy(1,1):xy(3,1), :));    
    % Loop over all slices in the stack
    for sli = 1:size(stack, 3)
        
        if pairwise
            if sli == 1
                first_fft = fft2(stack(:,:, sli));
            else
                first_fft = fft2(stack(:, :, sli-1));
            end
        end
        % Fourier transform of the current slice
        regframe = fft2(stack(:,:,sli));
        
        % Estimate the pixel shift using DFT registration
        [pixelShift_table(:, sli), ~] = dft_registration(first_fft, regframe);
    end
end

