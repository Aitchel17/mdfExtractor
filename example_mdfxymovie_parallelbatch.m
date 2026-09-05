% Batch extract, in two stages.
%
% Stage 1 is the only part a person sits through: the reference channel, the motion box and
% the two camera ROIs, one file after another. Stage 2 needs nobody: two parfors on one pool,
% first mdf_xymoviemain per file for the two channels, then the other streams per file --
% the analog channels and the camera. One worker per file is the finest the parallelism
% goes: MCSX holds a .mdf exclusively, so no object may keep a control open across the
% stages and no recording may be split in two. Nothing held grows with the recording;
% param.readlength frames is the ceiling per worker.

param.mdf_dir       = '';     % '' asks. Otherwise a folder holding the .mdf files
param.frame_start   = 5;      % the first frames are the scanner settling
param.readlength    = 2000;   % frames one read holds, the memory ceiling (count)
param.groupz        = 10;     % frames averaged into one page
param.motion_clahe  = true;   % local contrast, drift estimate only (logical)
param.motion_wiener = true;   % wiener2 and the low-pass after it (logical)
param.drift_channel = 1;      % the reference image and the drift come from this one
param.other_channel = 2;      % written after, through the same table
param.n_worker      = 4;      % one file per worker; MCSX locks a .mdf, so that is the floor
param.n_thread      = 6;      % computational threads per worker; n_worker x this = cores

if isempty(param.mdf_dir)
    param.mdf_dir = uigetdir();
end
mdf_list = dir(fullfile(param.mdf_dir, '*.mdf'));
mdf_name = {mdf_list.name};
fprintf('%d .mdf in %s\n', numel(mdf_name), param.mdf_dir);

%% Stage 1 -- one QC per file, nothing long runs
files   = cell(1, numel(mdf_name));
periphs = cell(1, numel(mdf_name));
for i = 1:numel(mdf_name)
    fprintf('\n=== %d of %d : %s ===\n', i, numel(mdf_name), mdf_name{i});
    mdf_path = fullfile(param.mdf_dir, mdf_name{i});
    files{i} = mdf_xymovie(mdf_path);
    [files{i}, demo] = files{i}.demoload(param.drift_channel, groupz=param.groupz);
    files{i} = files{i}.demomotion(demo, motion_clahe=param.motion_clahe, ...
        motion_wiener=param.motion_wiener);
    periphs{i} = mdf_peripheral(mdf_path);
    periphs{i} = periphs{i}.loadbehavior();
    files{i}.info.behavior_enable = periphs{i}.behavior_enable;   % goes out with the 2P info
end

%% Stage 2 -- no one has to be here
% a bare parfor opens a pool at the profile's size, not param.n_worker, and gives
% every worker one computational thread. NumThreads hands them back

% initialize parellel process worker
pool = gcp('nocreate'); % current pool
if isempty(pool) || pool.NumWorkers ~= param.n_worker || ... % if no pool or mismatch with setup
        pool.Cluster.NumThreads ~= param.n_thread
    delete(pool);            % double tap kill
    cluster = parcluster('Processes'); % thread can not handle mcsx independently
    cluster.NumThreads = param.n_thread; % number of thread per process
    parpool(cluster, param.n_worker); % distribute thread to process
end

parfor (i = 1:numel(files), param.n_worker)
    mdf_xymoviemain(files{i}, frame_start=param.frame_start, ...
        readlength=param.readlength, other_channel=param.other_channel);
    fprintf('=== %d of %d two channels done : %s ===\n', i, numel(files), mdf_name{i});
end

parfor (i = 1:numel(periphs), param.n_worker)
    periph = periphs{i};
    periph.analog = periph.loadanalog();
    periph.saveanalog;
    if periph.behavior_enable
        periph = periph.openavi();
        for idx = 1:periph.behavior.fcount
            frame = periph.loadbehaviorframe(idx);
            periph.saveeye(frame);
            periph.savewhisker(frame);
        end
        periph = periph.closeavi();
    end
    fprintf('=== %d of %d other streams done : %s ===\n', i, numel(periphs), mdf_name{i});
end
