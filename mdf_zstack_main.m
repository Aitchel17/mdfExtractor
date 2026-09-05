% Every Image Stack in a folder, each channel one read at a time. Every line calls a
% method; the padding the sinusoidal correction left is measured per channel off the
% window's first frames, and the pages go straight to <name>_ch<k>.tif.

param.zstack_dir = '';          % '' asks. Otherwise a folder holding the .mdf files
param.readlength = 500;         % frames one read holds, the memory ceiling (count)
param.channels   = [1 2];       % written in this order

if isempty(param.zstack_dir)
    param.zstack_dir = uigetdir();
end
mdf_list = dir(fullfile(param.zstack_dir, '*.mdf'));
mdf_name = {mdf_list.name};

for idx = 1:numel(mdf_name)
    mdfstack = mdf_zstack(fullfile(param.zstack_dir, mdf_name{idx}));
    mdfstack = mdfstack.updatestate(loadstart=1, loadend=mdfstack.info.fcount, ...
        readlength=param.readlength);
    for channel = param.channels
        mdfstack = mdfstack.updatestate(ch2read=channel);
        mdfstack = mdfstack.probepad();
        mdfstack = mdfstack.opentiff();
        for frame = mdfstack.state.loadstart : mdfstack.state.readlength : mdfstack.state.loadend
            mdfstack = mdfstack.updatestate(currentframe=frame);
            mdfstack.stack = mdfstack.loadframes;
            mdfstack.savetiff;
        end
        mdfstack = mdfstack.closetiff();
    end
    mdfstack.info = mdfstack.state2info();
    mdfstack.saveinfo;
end
