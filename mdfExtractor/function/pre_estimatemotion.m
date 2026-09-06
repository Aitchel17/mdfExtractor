function [pixelShift_table] = pre_estimatemotion(stack,reference_img,Vertices,pairwise)
arguments
    stack
    reference_img
    Vertices
    pairwise = false
end

    xy = round(Vertices);

    % Extract the selected region from the stack, and take each plane's mean over it out
    stack = stack(xy(1,2):xy(3,2), xy(1,1):xy(3,1), :);
    stack = double(stack);
    stack = stack - mean(stack, [1 2]);

    % Initialize the table to store pixel shifts
    pixelShift_table = zeros(4, size(stack, 3));  % 4 rows for shift values (x, y, and shifts)
    
    
    % Perform Fourier Transform on the reference, the same region with its mean out
    reference = double(reference_img(xy(1,2):xy(3,2), xy(1,1):xy(3,1)));
    reference = reference - mean(reference, 'all');
    first_fft = fft2(reference);
    % Loop over all slices in the stack; a pair with no structure on either side measured nothing
    for sli = 1:size(stack, 3)
        if pairwise
            if sli == 1
                reference = stack(:, :, sli);
            else
                reference = stack(:, :, sli-1);
            end
            first_fft = fft2(reference);
        end
        current = stack(:, :, sli);
        if ~any(reference, 'all') || ~any(current, 'all')
            pixelShift_table(:, sli) = [1; 0; 0; 0];
            continue
        end
        regframe = fft2(current);
        % Estimate the pixel shift using DFT registration
        [pixelShift_table(:, sli), ~] = dft_registration(first_fft, regframe);
    end
end

