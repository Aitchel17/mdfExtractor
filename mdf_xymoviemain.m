function file1 = mdf_xymoviemain(file1, opt)
%MDF_XYMOVIEMAIN  A QC'd recording's two channels, extracted without ever holding it, in two passes.
%   Caller: example_mdfxymovie_parallelbatch, stage 2
%
% IN   file1              1 x 1 mdf_xymovie   after demoload and demomotion
%      opt.frame_start    1 x 1 double   first acquisition frame (default 5, the scanner settling)
%      opt.frame_end      1 x 1 double   last (default Inf, the recording's end)
%      opt.readlength     1 x 1 double   frames one read holds, the memory ceiling (default 2000)
%      opt.other_channel  1 x 1 double   written second, through the drift channel's table
%                                        (default: the channel that is not motion_refchannel)
% OUT  file1              1 x 1 mdf_xymovie   with its drift table and the info it wrote
%
%   Every line calls a method; what crosses the lines lives on the object (stack, drifttable,
%   the open writer). Pass 1 walks the .mdf once on the drift channel, measuring the drift
%   read by read and writing as it goes; pass 2 writes the other channel through the same
%   table. Frames keep their full size, with -2048 (black) where a shift moved nothing in.
%   Peak memory is about two reads of opt.readlength frames, not the length of the recording.
    arguments
        file1
        opt.frame_start   (1,1) {mustBeNumeric} = 5
        opt.frame_end     (1,1) {mustBeNumeric} = Inf
        opt.readlength    (1,1) {mustBeNumeric} = 2000
        opt.other_channel (1,1) {mustBeNumeric} = 3 - file1.state.motion_refchannel
    end
    frame_end = min(opt.frame_end, file1.info.fcount);

    %% pass 1 -- the drift channel: measured read by read, written as it goes
    file1 = file1.updatestate(ch2read=file1.state.motion_refchannel, loadstart=opt.frame_start, ...
        loadend=frame_end, readlength=opt.readlength);
    file1 = file1.opentiff();
    for frame = file1.state.loadstart : file1.state.readlength : file1.state.loadend
        file1 = file1.updatestate(currentframe=frame);
        file1.stack      = file1.loadframes;           % currentframe, plus the overlap each side
        file1.drifttable = file1.getdrifttable();      % this read's columns written into the table
        file1.stack      = file1.correctdrift();       % the table interpolated onto the own frames
        file1.stack      = file1.afterprocess();       % groupz frames into one page
        file1.savetiff;                                % onto the open writer, at this read's pages
    end
    file1 = file1.closetiff();
    file1.savemotion;

    %% pass 2 -- the other channel through the same table
    file1 = file1.updatestate(ch2read=opt.other_channel);
    file1 = file1.opentiff();
    for frame = file1.state.loadstart : file1.state.readlength : file1.state.loadend
        file1 = file1.updatestate(currentframe=frame);
        file1.stack = file1.loadframes;
        file1.stack = file1.correctdrift();
        file1.stack = file1.afterprocess();
        file1.savetiff;
    end
    file1 = file1.closetiff();
    file1.stack = [];   % empty memory

    %%
    file1.info = file1.state2info();
    file1.saveinfo;
end
