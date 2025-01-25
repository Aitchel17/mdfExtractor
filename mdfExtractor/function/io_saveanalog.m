function io_saveanalog(analogdata, analoginfo,filename)
    fileID = fopen(filename, 'w');
    
    % Header start
    fprintf(fileID, '--- Analog Info ---\n');
    % Write the struct fields and their values
    fieldNames = fieldnames(analoginfo); % Get the field names
    for i = 1:numel(fieldNames)
        fieldName = fieldNames{i};
        fieldValue = analoginfo.(fieldName);
        % Convert arrays/matrices to a string for writing
        if isnumeric(fieldValue)
            fieldValueStr = mat2str(fieldValue); % Converts numbers to string
        elseif ischar(fieldValue)
            fieldValueStr = fieldValue; % Keep strings as-is
        end
        % Write the field name and value to the file
        fprintf(fileID, '%s: %s\n', fieldName, fieldValueStr);
    end
    % end of header
     fprintf(fileID, '\n--- Analog Data (unit V) ---\n');
    % Write the data row by row (field names as row names)
    channelNames = fieldnames(analogdata); % Field names are row names
    for i = 1:numel(channelNames)
        rowName = channelNames{i}; % Get the row name (field name)
        rowData = analogdata.(rowName); % Get the corresponding data
        rowData = mat2str(rowData); % Convert to a string
        % Write the row name and its data
        fprintf(fileID, '%s: %s\n', rowName, rowData);
    end
    %% Close the file
    fclose(fileID);
end
