clc,clear
nfiles = 6; % Specify the number of files
files = cell(1, nfiles); % Preallocate cell array to hold file objects
%%
for i = 1:nfiles
    % Create and initialize file object
    files{i} = mdf_xymovie();
    files{i}.state = files{i}.demo(1, 'groupz', 10); % Initial state
    files{i} = files{i}.loadbehavior();
end

%% a

missed = [1,4,5,9,11];
for i = missed
    files{i}.state = files{i}.demo(2, 'groupz', 10); % Initial state
    disp(i)

end
%%

for i = missed

    files{i}.state = files{i}.updatestate("loadstart", 5); % Update state

    % Channel 1 Processing
    files{i}.stack = files{i}.loadframes();
    files{i}.drifttable = files{i}.getdrifttable(); % Calculate drift
    files{i}.stack = files{i}.correctdrift(); % Correct drift
    files{i}.stack = files{i}.afterprocess(); % After process (default: groupz)
    % files{i}.showstack(); % Explore the stack
    files{i}.info = files{i}.state2info(); % Update state info
    files{i}.savetiff(); % Save TIFF
    files{i}.stack = []; % Clear memory
end

%%
% Second channel processing
for i = missed

    % Channel 2 Processing
    files{i}.state = files{i}.updatestate('ch2read', 2); % Update state for channel 2
    files{i}.stack = files{i}.loadframes();
    files{i}.stack = files{i}.correctdrift(); % Use drift table from channel 1
    files{i}.stack = files{i}.afterprocess(); % After process
    files{i}.info = files{i}.savetiff(); % Save and update info
    files{i}.stack = [];

    % Save information and analog data
    files{i}.info = files{i}.state2info(); % Bring state information to info
    files{i}.saveinfo(); % Save info
    files{i}.savecompbehavior();
    disp(i)

end



%% First channel processing
for i = 1:nfiles
    disp(i)
    files{i}.state = files{i}.updatestate("loadstart", 5); % Update state

    % Channel 1 Processing
    files{i}.stack = files{i}.loadframes();
    files{i}.drifttable = files{i}.getdrifttable(); % Calculate drift
    files{i}.stack = files{i}.correctdrift(); % Correct drift
    files{i}.stack = files{i}.afterprocess(); % After process (default: groupz)
    % files{i}.showstack(); % Explore the stack
    files{i}.info = files{i}.state2info(); % Update state info
    files{i}.savetiff(); % Save TIFF
    files{i}.stack = []; % Clear memory
end

%% Second channel processing
for i = 1:nfiles

    % Channel 2 Processing
    files{i}.state = files{i}.updatestate('ch2read', 2); % Update state for channel 2
    files{i}.stack = files{i}.loadframes();
    files{i}.stack = files{i}.correctdrift(); % Use drift table from channel 1
    files{i}.stack = files{i}.afterprocess(); % After process
    files{i}.info = files{i}.savetiff(); % Save and update info
    files{i}.stack = [];

    % Save information and analog data
    files{i}.info = files{i}.state2info(); % Bring state information to info
    files{i}.saveinfo(); % Save info
    files{i}.savecompbehavior();
    disp(i)

end
%% Just one touch
for i = 1:nfiles
    disp(i)
    files{i}.state = files{i}.updatestate("loadstart", 5); % Update state

    % Channel 1 Processing
    files{i}.stack = files{i}.loadframes();
    files{i}.drifttable = files{i}.getdrifttable(); % Calculate drift
    files{i}.stack = files{i}.correctdrift(); % Correct drift
    files{i}.stack = files{i}.afterprocess(); % After process (default: groupz)
    % files{i}.showstack(); % Explore the stack
    files{i}.info = files{i}.state2info(); % Update state info
    files{i}.savetiff(); % Save TIFF
    files{i}.stack = []; % Clear memory
    % Channel 2 Processing
    files{i}.state = files{i}.updatestate('ch2read', 1); % Update state for channel 2
    files{i}.stack = files{i}.loadframes();
    files{i}.stack = files{i}.correctdrift(); % Use drift table from channel 1
    files{i}.stack = files{i}.afterprocess(); % After process
    files{i}.info = files{i}.savetiff(); % Save and update info
    files{i}.stack = [];

    % Save information and analog data
    files{i}.info = files{i}.state2info(); % Bring state information to info
    files{i}.saveinfo(); % Save info
    files{i}.savecompbehavior();
    disp(i)
end




%%
for i = [1,3]
    % Create and initialize file object

    files{i}.state = files{i}.demo(2, 'groupz', 5); % Initial state
end
%%
for i = [1,3]
    disp(i)
    files{i}.state = files{i}.updatestate("loadstart", 5); % Update state

    % Channel 1 Processing
    files{i}.stack = files{i}.loadframes();
    files{i}.drifttable = files{i}.getdrifttable(); % Calculate drift
    files{i}.stack = files{i}.correctdrift(); % Correct drift
    files{i}.stack = files{i}.afterprocess(); % After process (default: groupz)
    % files{i}.showstack(); % Explore the stack
    files{i}.info = files{i}.state2info(); % Update state info
    files{i}.savetiff(); % Save TIFF
    files{i}.stack = []; % Clear memory

    % Channel 2 Processing
    files{i}.state = files{i}.updatestate('ch2read', 2); % Update state for channel 2
    files{i}.stack = files{i}.loadframes();
    files{i}.stack = files{i}.correctdrift(); % Use drift table from channel 1
    files{i}.stack = files{i}.afterprocess(); % After process
    files{i}.info = files{i}.savetiff(); % Save and update info
    files{i}.stack = [];

    % Save information and analog data
    files{i}.info = files{i}.state2info(); % Bring state information to info
    files{i}.saveinfo(); % Save info
end
