%%%%%%%%%%%%%%%%%%%%%%%%
% Prerequisite: MCSX 
%                       >> https://www.sutter.com/MICROSCOPES/mcs.html

% FUNCTION NAME:    io_tpsm
%
% DESCRIPTION:      Sutter .mdf Data input - output function
% INPUT:            .mdf
%
% NOTES:            If wavelength and objective length 
%
% WRITTEN BY:       C. Hyunseok Lee 2024-09-14
%
%%%%%%%%%%%%%%%%%%%%%%%%
function [info, mobj] = mdf_init(path,mdfname)

    %%
    switch nargin
        case 2
            mdfPath = fullfile(path,mdfname);
        case 1
            mdfPath = path;
        otherwise
           [info.mdfName, info.mdfPath] = uigetfile({'*.mdf'}); % select file by UI
           mdfPath = [info.mdfPath, info.mdfName];
    end
   
    disp([info.mdfName,'is loaded'])
    mobj = actxserver('MCSX.Data'); % Create Component Object Model (COM)
    mobj.invoke('OpenMCSFile', mdfPath); % Using COM open .mdf file
    
    % General Info
    info.User = mobj.ReadParameter('Created by');
    info.Date = mobj.ReadParameter('Created on');
    info.Comments = mobj.ReadParameter('Comments');
    
    % two photon scanning microscope info
    info.scanmode      = mobj.ReadParameter('Scan Mode');
    info.pclock        = mobj.ReadParameter('Pixel Clock');
    info.yoffset       = mobj.ReadParameter('Y Frame Offset');
    info.xoffset       = mobj.ReadParameter('X Frame Offset');
    info.rotation      = mobj.ReadParameter('Rotation');

    % Objective info
    info.objname       = mobj.ReadParameter('Objective');
    info.objpix        = mobj.ReadParameter('Microns per Pixel');
    info.objx          = mobj.ReadParameter('X Position');
    info.objy          = mobj.ReadParameter('Y Position');
    info.objz          = mobj.ReadParameter('Z Position');
    
    % Scan info
    info.zoom          = mobj.ReadParameter('Magnification');
    info.excitation          = strcat(mobj.ReadParameter('Laser Wavelength (nm)'),' nm');
    info.fbit          = mobj.ReadParameter('Frame Bit Depth');
    info.fduration          = mobj.ReadParameter('Frame Duration (s)');
    info.fcount        = str2double(mobj.ReadParameter('Frame Count'));
    info.finterval          = mobj.ReadParameter('Frame Interval (ms)');
    info.fps           = 1/str2double(info.fduration(1:end-1)); % Hz
    info.fheight            = str2double(mobj.ReadParameter('Frame Height'));
    info.fwidth            = str2double(mobj.ReadParameter('Frame Width'));
    info.laserpower        = mobj.ReadParameter('Laser intensity');
    % Imaging Channel info
    info.imgch0name    = mobj.ReadParameter('Scanning Ch 0 Name');
    info.imgch0range   = mobj.ReadParameter('Scanning Ch 0 Input Range');
    info.imgch1name    = mobj.ReadParameter('Scanning Ch 1 Name');
    info.imgch1range   = mobj.ReadParameter('Scanning Ch 1 Input Range');
    % initialize analog

%% Scan mode specific info
    if strcmp(info.scanmode, 'Image Stack')
        disp('Image stack loaded')
        info.fave      = mobj.ReadParameter('Average Count');
        info.pinit     = mobj.ReadParameter('Initial Intensity');
        info.pfinl     = mobj.ReadParameter('Final Intensity'); % final intensity activex control has bug the .ocx file should be
        % editted
        info.zinter    = mobj.ReadParameter('Z- interval');
    end

end