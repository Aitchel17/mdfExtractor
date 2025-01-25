function mergedStruct = util_mergestruct(struct1, struct2)
    % Merge two structures, with struct2 fields overwriting struct1 fields if overlapping
    fields1 = fieldnames(struct1);
    fields2 = fieldnames(struct2);
    values1 = struct2cell(struct1);
    values2 = struct2cell(struct2);

    % Combine fields and values
    allFields = [fields1; fields2];
    allValues = [values1; values2];

    % Handle duplicate fields (struct2 overwrites struct1)
    [~, uniqueIdx] = unique(allFields, 'last');
    mergedStruct = cell2struct(allValues(uniqueIdx), allFields(uniqueIdx), 1);
end
