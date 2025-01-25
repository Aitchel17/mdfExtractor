function [analog, info] = mdf_readanalog(mobj)
    info.analogfreq    = mobj.ReadParameter('Analog Acquisition Frequency (Hz)');
    info.analogcount   = str2double(mobj.ReadParameter('Analog Sample Count'));
    info.analogresolution   = mobj.ReadParameter('Analog Resolution');

    for analog_ch = string(0:1:7)
        field_name = mobj.ReadParameter(sprintf('Analog Ch %s Name',analog_ch));

        if strcmp(field_name,"")
            fprintf('\nAnalog Ch %s not detected',analog_ch);
        else
            channel_fname = [field_name,'_channel'];
            info.(channel_fname) = str2double(analog_ch);
            range_fname = [field_name,'inputrange'];
            range_call = sprintf('Analog Ch %s Input Range',analog_ch);
            info.(range_fname) = mobj.ReadParameter(range_call);          
            fprintf('\nAnalog Ch %s is %s\n',analog_ch,field_name);
            analog.(['raw_',field_name]) = double(mobj.ReadAnalog(str2double(analog_ch)+1,info.analogcount,0));
        end
    end
end

