% Change groupz if you are using galvo which already scan slowly and does
% not require group averazing
% remove channel 2 processing or change .demo() function first argument to
% the other argument.

file1 = mdf_xymovie();
file1.state = file1.demo(1,groupz=10); % state for image correction generated at here, reference channel and ch2read set with first argument
file1.state = file1.updatestate("loadstart",5); % update state
file1.stack = file1.loadframes;
file1.drifttable = file1.getdrifttable(); % calculate drift using refimg
file1.stack = file1.correctdrift(); % correctdrift
file1.stack = file1.afterprocess(); % afterprocess default: groupz only, option: thresholding
file1.showstack(); % explore the stack
file1.info = file1.state2info();
file1.savetiff; % save
file1.stack = []; % empty memory
% Channel 2 Processing 
file1.state = file1.updatestate('ch2read',2);
file1.stack = file1.loadframes;
file1.stack = file1.correctdrift; % just use drifttable yield from channel 1
file1.stack = file1.afterprocess();
file1.info = file1.savetiff; % update info with final saving fps
% update information and save
file1.info = file1.state2info(); % bring state information to info section for saving purpose
% save information
file1.saveinfo;
file1.saveanalog;