% Every Image Stack in a folder: pixel shift settled on the first file, then per file load -
% register each plane against the median of the corrected planes before it - move - cut -
% write, both channels into one <name>_merged.tif beside _motion.txt and _info.txt.

param.zstack_dir    = '';       % '' asks. Otherwise a folder holding the .mdf files
param.drift_channel = 1;        % the box is drawn and the steps measured on this one
param.other_channel = 2;        % written after, through the same table
param.motion_clahe  = false;    % local contrast, drift estimate only (logical). Off: lets no-information planes past the regerror gate, see CLAUDE_LOG.md

if isempty(param.zstack_dir)
    param.zstack_dir = uigetdir();
end
mdf_list = dir(fullfile(param.zstack_dir, '*.mdf'));
mdf_name = {mdf_list.name};
%%
xshift = [];   % settled on the first file, then handed to the rest; [] asks
for idx = 1:3 %numel(mdf_name)
    % the recording, and the state for image correction: pixel shift, padding
    mdfstack = mdf_zstack(fullfile(param.zstack_dir, mdf_name{idx}));
    mdfstack = mdfstack.demoload(param.drift_channel, xshift=xshift);
    mdfstack = mdfstack.updatestate(readlength=mdfstack.info.fcount);   % the whole stack, one read
    mdfstack.stack = mdfstack.loadframes;
    mdfstack = mdfstack.demomotion(motion_clahe=param.motion_clahe);   % preprocess - register against the running reference
    xshift = mdfstack.state.xshift;
    [row_range, col_range] = mdfstack.getcropbounds();                   % the region every moved plane covers

    % the drift channel, moved by its applied shifts and cut, held for the file
    mdfstack.stack = mdfstack.correctdrift(row_range, col_range);
    drift_stack = mdfstack.stack;
    mdfstack.savemotion;

    % the other channel through the same table and the same cut, then both into one file
    mdfstack = mdfstack.updatestate(ch2read=param.other_channel);
    mdfstack.stack = mdfstack.loadframes;
    mdfstack.stack = mdfstack.correctdrift(row_range, col_range);
    mdfstack = mdfstack.opentiff();
    mdfstack.savetiff(drift_stack);
    mdfstack = mdfstack.closetiff();
    mdfstack.stack = [];   % empty memory

    % what was settled, with the 2P record
    mdfstack.info = mdfstack.state2info();
    mdfstack.saveinfo;
end
