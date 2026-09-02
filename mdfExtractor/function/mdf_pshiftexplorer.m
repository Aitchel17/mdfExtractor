function [pshift] = mdf_pshiftexplorer(stack)
%MDF_PSHIFTEXPLORER  reveal mismatch stripe by averaging stack, preview of corrected result.
%
% IN   stack   H x W x T int16   raw frames, margins still at -2048
% OUT  pshift  1 x 1 double      columns the even lines are moved by

    disp('Post pixel shift correction, check image');
    clim_floor  = -32;                          % below the PMT baseline, above the margins
    meanproject = mean(double(stack), 3);
    clim_range  = [clim_floor, max(meanproject, [], 'all')];

    fig = uifigure('Name', 'Pixel Shift Correction', 'Position', [100, 100, 532, 280]);
    imgPanel     = uipanel(fig, 'Title', 'Mean Projection', 'Position', [10, 110, 512, 160]);
    controlPanel = uipanel(fig, 'Title', 'Console', 'Position', [10, 10, 512, 100]);
    ax   = uiaxes(imgPanel, 'Position', [0, 0, 512, 128]);
    hImg = imshow(meanproject, clim_range, 'Parent', ax);

    uicontrol('Style', 'text', 'Parent', controlPanel, 'Position', [20, 40, 50, 20], 'String', 'pShift:');
    pshiftEdit = uieditfield(controlPanel, 'numeric', 'Position', [70, 40, 30, 30], 'Value', 0, ...
        'ValueChangedFcn', @(src, event) previewShift(src.Value));

    uicontrol('Style', 'text', 'Parent', controlPanel, 'Position', [150, 40, 100, 20], 'String', 'Intensity Range:');
    uislider(controlPanel, 'range', 'Value', clim_range, 'Limits', clim_range, ...
        'Position', [250, 70, 200, 3], ...
        'ValueChangingFcn', @(src, event) updateContrast(event.Value));

    uicontrol('Style', 'pushbutton', 'Parent', controlPanel, 'Position', [400, 5, 80, 30], ...
        'String', 'Confirm', 'Callback', @(src, event) uiresume(gcbf));
    uiwait(fig);

    pshift = pshiftEdit.Value;
    close(fig);
    disp(['Post xshift pixel = ' num2str(pshift)]);

    function updateContrast(vrange)
        ax.CLim = vrange;
    end

    % CLim is never recomputed here, so two pshift values are seen on one scale
    function previewShift(shift_by)
        shifted = mdf_pshiftcorrection(stack, shift_by);
        preview = mean(double(shifted), 3);
        hImg.CData = preview;
        ax.XLim = [0.5, size(preview, 2) + 0.5];
        title(ax, sprintf('Preview of Mean Projection (pShift = %d)', shift_by));
    end
end
