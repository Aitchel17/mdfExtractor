function [selectedLens, pixelSize] = mdf_objectiveselector()
    %IO_OBJECTIVESELECTOR Displays a dialog for selecting an objective lens
    %   Returns the selected lens and its corresponding pixel size

    % Define a list of objective lenses and their corresponding pixel sizes
    objectiveList = {'16x 0.8NA resonant', '16x 0.8NA galvo'};
    pixelSizes = [0.57, 0.815]; % Pixel sizes corresponding to each lens
    
    % Display a dialog box for selection
    selectionIndex = listdlg('PromptString', 'Select an objective lens:', ...
                                      'SelectionMode', 'single', ...
                                      'ListString', objectiveList, ...
                                      'Name', 'Objective Selection');
    
    % Return the selected lens and its pixel size
    selectedLens = objectiveList{selectionIndex};
    pixelSize = pixelSizes(selectionIndex);
end