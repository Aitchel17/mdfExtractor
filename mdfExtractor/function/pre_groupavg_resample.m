function [outputArg1,outputArg2] = pre_groupavg_resample(imagestack,fpsin, fpsout)
%PRE_GROUPAVG_RESAMPLE Summary of this function goes here
    % This function is designed to resample the image stack [x,y,t1] to [x,y,t2]
    % t1 and t2 has fps of fpsin and fpsout
%   Detailed explanation goes here
    stack_dim = size(imagestack);
    tin_dim = stack_dim(3);
    tout_dim = round(t_dim*fpsout/fpsin);
    collapsed_1d = reshape(imagestack,[],t_dim).';
    collapsed_1d = gpuArray(collapsed_1d);
    %%
    collapsed_1d_fft = fft(collapsed_1d,[],1);
    Yf = padcrop_spectrum_1d(collapsed_1d_fft, tin_dim, tout_dim);   % [Tout × P]
    %%
    npoint = size(collapsed_1d_fft,2);
    %%
    low_passed_freq = zeros(tout)



end

