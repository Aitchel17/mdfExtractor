% Example of mdf_xy_multiplane class
% Example mdf xy_movie is 
%   recorded at imaging channel = 2, total number of plane = 1
% mdf_xy_multiplane is subclass of mdf_xymovie subsub class of mdf

%%
clear, clc
file1 = mdf_xy_mutiplane(); % initialize instance file1 connected to target .mdf file, load analog and scanning info
%%
file1.state = file1.updatestate('num_plane',2,"loadstart",3); % set loading parameter
file1.state = file1.demo(2,1); % (clear img channel, clear plane) set preprocessing parameter default 10 frame averaging

% You can open multiple files and process user interaction at the beginning 
% file2.state = file2.updatestate('num_plane',2,"loadstart",3); % 
% file2.state = file2.demo(2,1); % 

file1.stack = file1.loadframes; % load frames from state.loadstart to state.loadend
file1.drifttable = file1.getdrifttable; % using region of interest and reference frame from demo function get drift table using dft correction
file1.stack = file1.correctdrift; % apply drift table
file1.state = file1.updatestate('groupz',1); % change frame averaging required for dft correction 
file1.stack = file1.afterprocess; % groupz projection (groupz=1, disabled), thresholding(optional)
file1.info = file1.savetiff; % save tifffile
file1.info = file1.state2info(); % integrate part of state information to information for saving purpose
file1.saveinfo() % save information as .txt file
file1.stack = []; % clear memory
file1.state = file1.updatestate('plane2read',2); % update loading parameter to other imaging plane 
file1.stack = file1.loadframes; % loading other imaging plane
% file1.drifttable = file1.getdrifttable; if drift table need to be
% calculate again, calculate again
file1.stack = file1.correctdrift; % apply drift table
file1.stack = file1.afterprocess; % this is disabiled as groupz is still not changed
file1.info = file1.savetiff; % save tiff file
file1.saveanalog; % save analog data

% file2.info = file2.state2info("loadstart",true,'xshift',true,'refframe',true,'motionvertices',true);
% file2.stack = file2.loadframes;
% file2.drifttable = file2.getdrifttable;
% file2.stack = file2.correctdrift;
% file2.state = file2.updatestate('groupz',1);
% file2.stack = file2.afterprocess;
% file2.info = file2.savetiff;
% file2.info = file2.state2info();
% file2.saveinfo()
% file2.state = file2.updatestate('plane2read',2);
% file2.stack = file2.loadframes;
% file2.stack = file2.correctdrift;
% file2.stack = file2.afterprocess;
% file2.info = file2.savetiff;
% file2.saveanalog;