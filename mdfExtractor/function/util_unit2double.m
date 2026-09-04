function value = util_unit2double(text)
%UTIL_UNIT2DOUBLE  The leading number of a unit-suffixed value, as a double.
%   Caller: mdf, mdf_get2pinfo, mdf_zstack.openstream, mdf_xymovie.openstream
%
% IN   text   1 x n char | 1 x 1 double   '0.285 um', '4x', '0.008091024 s', or a number
% OUT  value  1 x 1 double
%
%   MCSX hands these back as text with the unit attached and mdf_objectiveselector
%   hands back a number, so both arrive. Nothing here counts the suffix, which is why
%   one function serves objpix, zoom, zinter and fduration alike. MCSX answers an
%   unknown parameter with 'No match', which carries no leading number -- that is NaN
%   and not the empty sscanf gives, because the callers divide by what comes out
    if isa(text, 'double')
        value = text;
        return
    end
    value = sscanf(text, '%f', 1);
    if isempty(value)
        value = NaN;
    end
end
