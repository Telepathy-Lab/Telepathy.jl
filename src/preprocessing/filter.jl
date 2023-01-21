function filter_data!(raw::Raw; lowPass=0, highPass=0, window=:kaiser)
    #@info "We filter."

    srate = raw.chans.srate[1]
    if (lowPass != 0) & (highPass != 0)
        if lowPass > highPass
            fType = Bandpass(highPass, lowPass, fs=srate)
        elseif highPass > lowPass
            fType = Bandstop(lowPass, highPass, fs=srate)
        else
            @error "Highpass and lowpass filters cannot have the same value."
        end
    elseif lowPass != 0
        fType = Lowpass(lowPass, fs=srate)
    elseif highPass != 0
        fType = Highpass(highPass, fs=srate)
    else
        @info "Neither highpass or lowpass value provided. Doing nothing!"
    end

    if window == :kaiser
        winType = FIRWindow(transitionwidth=10/srate)
    else
        winType = FIRWindow(eval(:($window(1411))))
    end

    digFilter = digitalfilter(fType, winType)
    @info length(digFilter)
    output = similar(raw.data)
    Threads.@threads for chan in axes(raw.data, 2)
        @inbounds @views output[:, chan] = filtfilt(digFilter, raw.data[:, chan])
    end
    output
end