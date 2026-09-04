%%%%%%%%%%%%%%%%%%%%%%%%
% Prerequisite: MCSX 
%                       >> https://www.sutter.com/MICROSCOPES/mcs.html

% FUNCTION NAME:    mdf_get2pinfo
%
% DESCRIPTION:      Sutter .mdf Data input - output function
% INPUT:            .mdf
%
% NOTES:            If wavelength and objective length 
%
% WRITTEN BY:       C. Hyunseok Lee 2024-09-14
%
%%%%%%%%%%%%%%%%%%%%%%%%
function info = mdf_get2pinfo(mobj)
% Get two photon imaging parameter from mobj

% IN   mobj  1 x 1 COM     an open MCSX.Data control
% OUT  info  1 x 1 struct  in the order saveinfo writes them to _info.txt
    info = struct();

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
    info.fps           = 1/util_unit2double(info.fduration); % Hz
    info.fheight            = str2double(mobj.ReadParameter('Frame Height'));
    info.fwidth            = str2double(mobj.ReadParameter('Frame Width'));
    info.laserpower        = mobj.ReadParameter('Laser intensity');
    % Imaging Channel info
    % black level varies between recordings; the name has no 'Scanning' prefix
    info.imgch0name    = mobj.ReadParameter('Scanning Ch 0 Name');
    info.imgch0range   = mobj.ReadParameter('Scanning Ch 0 Input Range');
    info.imgch0black   = readparam_ornan(mobj, 'Ch 0 black level');
    info.imgch0gain    = readparam_ornan(mobj, 'Integrator 0 gain');
    info.imgch1name    = mobj.ReadParameter('Scanning Ch 1 Name');
    info.imgch1range   = mobj.ReadParameter('Scanning Ch 1 Input Range');
    info.imgch1black   = readparam_ornan(mobj, 'Ch 1 black level');
    info.imgch1gain    = readparam_ornan(mobj, 'Integrator 1 gain');
    % initialize analog

%% Scan mode specific info
    if strcmp(info.scanmode, 'Image Stack')
        info.fave      = mobj.ReadParameter('Averaging Count');
        info.pinit     = mobj.ReadParameter('Initial Intensity');
        info.pfinl     = mobj.ReadParameter('Final Intensity'); % final intensity activex control has bug the .ocx file should be
        % editted
        info.zinter    = mobj.ReadParameter('Z- interval');
        info.pcontol   = mobj.ReadParameter('Intensity Control');
        info.repeat    = mobj.ReadParameter('Stack Repeat Count');
    end
end
function value = readparam_ornan(mobj, name)
%READPARAM_ORNAN  A parameter the file may not carry, as a number or NaN.
%   ReadParameter returns the string 'No match' for a name it does not know.
%
%   IN   mobj   1x1 COM     the open MCSX.Data control
%        name   1xM char    the parameter name, exactly as MCSX spells it
%   OUT  value  1x1 double  the number, or NaN when absent or unparseable
    raw = mobj.ReadParameter(name);
    if strcmp(raw, 'No match') || isempty(strtrim(raw))
        value = NaN;
        return
    end
    value = str2double(raw);
end
