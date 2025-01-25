function [stack] = pre_groupaverage(stack, number_averaging)
    % This function performs group averaging of a 3D z-stack.
    % It averages consecutive frames in the z-stack.
    % The frames are grouped into sets of `number_averaging` frames, 
    % and the average is calculated for each group.
    % Any frames that don't complete a full group are discarded.
    %
    % Inputs:
    %   zstack         - A 3D matrix (height x width x num_frames).
    %   number_averaging - The number of frames to average together.
    %
    % Outputs:
    %   result         - The resulting 3D matrix with the averaged frames.
    
    % Ensure the number of frames is a multiple of the group size
    if number_averaging == 1
        disp('skip group averaging')
    else
        depricate_frame = mod(size(stack,3),number_averaging);
        disp(['Group averaging with ' num2str(number_averaging) ' depricate ' num2str(depricate_frame)]);
        stack = stack(:,:,1:size(stack,3)-depricate_frame);
    
        % Reshape the stack to group the frames
        stack = reshape(stack, size(stack, 1), size(stack, 2), number_averaging, []);
        
        % Calculate the mean of each group of frames along the 3rd dimension
        stack = squeeze(mean(stack, 3)); % Average along the 3rd dimension (grouped frames)
    end
end