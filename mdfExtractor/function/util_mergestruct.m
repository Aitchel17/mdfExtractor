function mergedStruct = util_mergestruct(struct1, struct2)
    mergedStruct = struct1;
    fields2 = fieldnames(struct2);
    for i = 1:numel(fields2)
        mergedStruct.(fields2{i}) = struct2.(fields2{i});
    end
end