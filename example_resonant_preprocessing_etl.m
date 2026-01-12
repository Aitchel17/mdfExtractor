
clear, clc
% make mcsx obj, get general (info), two photon scanning microscope imaging (info_ tpsm), and imaging mode specific (info_mode)  

file1 = mdf_xymovie();

file1.state = file1.updatestate('num_plane',2);
file1.state = file1.demo(2,'plane2read',1); 
file1.info = file1.state2info("loadstart",true,'xshift',true,'refframe',true,'motionvertices',true);
file1.stack = file1.loadframes;
file1.drifttable = file1.getdrifttable;
file1.stack = file1.correctdrift;
file1.state = file1.updatestate('groupz',1);

file1.stack = file1.afterprocess;
file1.info = file1.savetiff;

% transfer loadend to state
file1.info = file1.state2info("loadend",true);
% save info
file1.saveinfo()

% set load parameter to 2nd plane
file1.state = file1.updatestate('plane2read',2);
% load 2nd plane 
file1.stack = file1.loadframes;
% correct drift table using previous
file1.stack = file1.correctdrift;
% groupaveraging
file1.stack = file1.afterprocess;
% save
file1.info = file1.savetiff;