zstack_dir = uigetdir();
%%
zstack_fname = dir(fullfile(zstack_dir,'*.mdf'));
zstack_fname = {zstack_fname.name};
%%
for idx = 1:numel(zstack_fname)
    mdfstack = mdf_zstack(fullfile(zstack_dir,zstack_fname{idx}));
    mdfstack.state.ch2read = 1;
    mdfstack.stack = mdfstack.loadframes;
    mdfstack.saveinfo
    mdfstack.savetiff
    mdfstack.state.ch2read = 2;
    mdfstack.stack = mdfstack.loadframes;
    mdfstack.savetiff
end