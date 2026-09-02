% Batch extract, in two stages.
%
% Stage 1 is the only part a person sits through: one demo() per file plus the eye
% and whisker rectangles. Stage 2 needs nobody, and holds nothing that grows with
% the recording -- param.chunk_frames is the ceiling. One worker per file is the
% finest the parallelism goes: MCSX holds a .mdf exclusively, so no object may
% keep a control open across the stages and no recording may be split in two.

param.mdf_dir       = '';     % '' asks. Otherwise a folder holding the .mdf files
param.frame_start   = 5;      % the first frames are the scanner settling
param.chunk_frames  = 2000;   % frames held at once, the memory ceiling (count)
param.groupz        = 10;
param.motion_clahe  = true;   % local contrast, drift estimate only (logical)
param.motion_wiener = true;   % wiener2 and the low-pass after it (logical)
param.drift_channel = 1;      % the drift is measured on this one, written first
param.other_channel = 2;      % written after, reusing that table; 0 to skip
param.n_worker      = 4;      % one file per worker; MCSX locks a .mdf, so that is the floor
param.n_thread      = 6;      % computational threads per worker; n_worker x this = cores

if isempty(param.mdf_dir)
    param.mdf_dir = uigetdir();
end
mdf_list = dir(fullfile(param.mdf_dir, '*.mdf'));
mdf_name = {mdf_list.name};
fprintf('%d .mdf in %s\n', numel(mdf_name), param.mdf_dir);

%% Stage 1 -- one QC per file, nothing long runs
files = cell(1, numel(mdf_name));
for i = 1:numel(mdf_name)
    fprintf('\n=== %d of %d : %s ===\n', i, numel(mdf_name), mdf_name{i});
    files{i} = mdf_xymovie(fullfile(param.mdf_dir, mdf_name{i}));
    [files{i}, d] = files{i}.demoload(param.drift_channel, groupz=param.groupz);
    files{i} = files{i}.demomotion(d, motion_clahe=param.motion_clahe, ...
        motion_wiener=param.motion_wiener);
    files{i} = files{i}.loadbehavior();
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
    info = mdf_streamextract(files{i}, ...
        frame_start   = param.frame_start, ...
        frame_end     = files{i}.info.fcount, ...
        chunk_frames  = param.chunk_frames, ...
        drift_channel = param.drift_channel, ...
        other_channel = param.other_channel);
    done = files{i};
    done.info = info;
    done.saveinfo();
    done.savebehavior();
    fprintf('=== %d of %d done : %s ===\n', i, numel(files), mdf_name{i});
end
