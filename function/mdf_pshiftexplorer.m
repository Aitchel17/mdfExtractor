function [pshift] = mdf_pshiftexplorer(stack)


    disp('Post pixel shift correction, check image');
    % Create the main figure
    fig = uifigure('Name', 'Pixel Shift Correction', 'Position', [100, 100, 532, 280]);
    
    % Create panels for controls and image display
    imgPanel = uipanel(fig, 'Title', 'Mean Projection', 'Position', [10, 110, 512, 160]);
    controlPanel = uipanel(fig, 'Title', 'Console', 'Position', [10, 10, 512, 100]);

    currentstack = stack;
    % Create UI Axes inside the panel
    ax = uiaxes(imgPanel, 'Position', [0, 0, 512, 128]);
    
    % Calculate the mean projection
    meanproject = mean(stack, 3);
    meanproject = meanproject - min(meanproject,[],'all');
    meanproject = meanproject/max(meanproject,[],'all');
    meanproject = meanproject*65535;

    disp_img = meanproject;
    
    % Display the image on the UI Axes
    hImg = imshow(disp_img, [0, 65536], 'Parent', ax);
    
    % Editable text box for pshift value input
    uicontrol('Style', 'text', 'Parent', controlPanel, 'Position', [20, 40, 50, 20], 'String', 'pShift:');
    % pshiftEdit = uicontrol('Style', 'edit', 'Parent', controlPanel, 'Position', [70, 40, 30, 30], 'String', '0');
    pshiftEdit = uieditfield(controlPanel, 'numeric', 'Position', [70, 40, 30, 30], 'Value', 0, ...
        'ValueChangedFcn', @(src, event) previewShift(stack, ax, src.Value, hImg));

    % Slider for adjusting display range dynamically
    uicontrol('Style', 'text', 'Parent', controlPanel, 'Position', [150, 40, 100, 20], 'String', 'Intensity Range:');
    vmin = int8(min(meanproject,[],'all'));
    vmax = int16(max(meanproject,[],'all'));
    uislider(controlPanel, "range", 'Value', [0, 65535],'Limits', [0, 65535] , 'Position', [250, 70, 200, 3], ...
        'ValueChangingFcn', @(src, event) updateContrast(hImg, event.Value));
    
        
    % Confirm button to resume execution
    uicontrol('Style', 'pushbutton', 'Parent', controlPanel, 'Position', [400, 5, 80, 30], ...
        'String', 'Confirm', 'Callback', @(src, event) uiresume(gcbf)); % Resume execution when clicked
    
    % Wait for confirmation
    uiwait(fig);

    pshift = pshiftEdit.Value;
    % Get the pshift value from the edit box
    close(fig);
    disp(['Post xshift pixel = ' num2str(pshift)]);
    % Update image dynamically with intensity range
    function updatefig(meanproject, hImg, vrange)
        hImg.CData = meanproject; % Keep the original data
        hImg.Parent.CLim = [vrange(1), vrange(2)]; % Adjust display range
    end

    % Preview function to simulate pixel shift
    % Update the contrast dynamically
        function updateContrast(hImg, vrange)
            hImg.Parent.CLim = [vrange(1), vrange(2)]; % Adjust display range
        end

     function previewShift(stack, ax, pshift, hImg)
        currentstack = mdf_pshiftcorrection(stack,pshift);

        % Update the preview image
        disp_img = mean(currentstack, 3);
        disp_img = disp_img - min(disp_img,[],'all');
        disp_img = disp_img/max(disp_img,[],'all');
        disp_img = disp_img*65536;
        hImg.CData = disp_img;
        title(ax, sprintf('Preview of Mean Projection (pShift = %d)', pshift));
    end

end
