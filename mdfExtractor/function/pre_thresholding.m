function [stack] = pre_thresholding(stack,option)
        arguments
            stack
            option.cutting_size = 4 % center area
            option.cutoff = 1 % cutoff bottom 1% tile
        end
%   Puropose: Double to uint16 for .tif saving function cause high minimum
%   value
%   Reason: 
%     pixel shift correction -> blank regions -> group averaged -> Very low
%     signal region but not 0 -> Rest of pixels are quite bright
%  Function: At the center of image, which will include at least one true
%  dim pixel. Calculate median of center region and select minimum value as
%  threshold

%   Detailed explanation goes here
    % rescale
    stack = gpuArray(stack);
    [height, width, ~] = size(stack);
    cutting_size = option.cutting_size;
    centerregion = stack(1+ceil(height/cutting_size):end-ceil(height/cutting_size),1+ceil(width/cutting_size):end-ceil(width/cutting_size),:);
    threshold = min(prctile(centerregion,option.cutoff,3),[],'all'); % minimum of 1/3 to 2/3 center region's bottom 1% percentile
    stack = stack-threshold;
    stack(stack<0) = 0;
    stack = gather(stack);
end

