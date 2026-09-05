% Every Image Stack in a folder, registered plane to plane on the way to disk. Every line
% calls a method; what crosses the lines lives on the object. Per file a person sets the
% pixel shift and draws the box; then pass 1 reads the drift channel one read at a time,
% measures each plane against the one before it and writes the planes moved by the sum;
% pass 2 writes the other channel through the same table. _motion.txt holds the steps,
% not their sum.

param.zstack_dir    = '';       % '' asks. Otherwise a folder holding the .mdf files
param.readlength    = 500;      % planes one read holds, the memory ceiling (count)
param.drift_channel = 1;        % the box is drawn and the steps measured on this one
param.other_channel = 2;        % written after, through the same table

if isempty(param.zstack_dir)
    param.zstack_dir = uigetdir();
end
mdf_list = dir(fullfile(param.zstack_dir, '*.mdf'));
mdf_name = {mdf_list.name};

for idx = 1:numel(mdf_name)
    %% the recording, and the state for image correction: pixel shift, padding, the box
    mdfstack = mdf_zstack(fullfile(param.zstack_dir, mdf_name{idx}));
    [mdfstack, demo] = mdfstack.demoload(param.drift_channel);
    mdfstack = mdfstack.demomotion(demo);
    mdfstack = mdfstack.updatestate(loadstart=1, loadend=mdfstack.info.fcount, ...
        readlength=param.readlength);

    %% pass 1 -- the drift channel: each plane against the one before, written as it goes
    mdfstack = mdfstack.opentiff();
    for frame = mdfstack.state.loadstart : mdfstack.state.readlength : mdfstack.state.loadend
        mdfstack = mdfstack.updatestate(currentframe=frame);
        mdfstack.stack      = mdfstack.loadframes;         % own planes, plus the one before
        mdfstack.drifttable = mdfstack.getdrifttable();    % this read's steps into the table
        mdfstack.stack      = mdfstack.correctdrift();     % each plane by the sum of its steps
        mdfstack.savetiff;
    end
    mdfstack = mdfstack.closetiff();
    mdfstack.savemotion;

    %% pass 2 -- the other channel through the same table
    mdfstack = mdfstack.updatestate(ch2read=param.other_channel);
    mdfstack = mdfstack.opentiff();
    for frame = mdfstack.state.loadstart : mdfstack.state.readlength : mdfstack.state.loadend
        mdfstack = mdfstack.updatestate(currentframe=frame);
        mdfstack.stack = mdfstack.loadframes;
        mdfstack.stack = mdfstack.correctdrift();
        mdfstack.savetiff;
    end
    mdfstack = mdfstack.closetiff();
    mdfstack.stack = [];   % empty memory

    %%
    mdfstack.info = mdfstack.state2info();
    mdfstack.saveinfo;
end
