function estimate_transition(highPass, lowPass, srate)
    if highPass != 0
        if highPass < 2
            hightrans = highPass
        else
            hightrans = max(2, highPass/4)
        end
    else
        # Highest possible value just for the sake of selection that comes next
        hightrans = srate
    end

    if lowPass != 0
        if lowPass * 1.25 > srate
            lowtrans = srate - lowPass
        else
            lowtrans = max(2, lowPass/4)
        end
    else
        # Highest possible value just for the sake of selection that comes next
        lowtrans = srate
    end        

    return min(hightrans, lowtrans)
end

function choose_type(highPass::Integer, lowPass::Integer, srate::Integer)
    if (lowPass != 0) & (highPass != 0)
        if lowPass > highPass
            fType = Bandpass(highPass, lowPass, fs=srate)
        elseif highPass > lowPass
            fType = Bandstop(lowPass, highPass, fs=srate)
        else
            @error "Highpass and lowpass filters cannot have the same value."
        end
    elseif highPass != 0
        fType = Highpass(highPass, fs=srate)
    elseif lowPass != 0
        fType = Lowpass(lowPass, fs=srate)
    else
        @info "Neither highpass or lowpass value provided. Doing nothing!"
    end
    return fType
end

mutable struct FilterDetails
    transition::Float64
    pbRipple::Float64
    ripple::Float64
    sideLobe::Integer
    attenuation::Integer
end

filterDetails = Dict(
    :rectangular    => FilterDetails(0.9, 0.741,  0.089,    -13, 21),
    :hann           => FilterDetails(3.1, 0.0546, 0.063,    -31, 44),
    :hanning        => FilterDetails(3.1, 0.0546, 0.063,    -31, 44),
    :hamming        => FilterDetails(3.3, 0.0194, 0.0022,   -41, 53),
    :blackman       => FilterDetails(5.5, 0.0017, 0.000196, -57, 74),
)

"""
    filterord(window::Symbol, transitionWidth::Integer, srate::Integer)

Estimate the order of the filter based on the window type and the chosen transition width.
This function covers the most popular non-adaptive windows.
"""
function filterord(window::Symbol, transitionWidth::Number)
    if !(window in keys(filterDetails))
        error("Window type not supported, please provide the filter order manually.")
    end

    winLength = ceil(Int, filterDetails[window].transition / transitionWidth)
    # Make sure the number of taps is odd
    return winLength |= 1
end

function estimate_window(window::Symbol, srate::Number, transitionWidth::Number, attenuation::Number=53) 
    if window == :kaiser
        # Kaiserord expects transition relative to Nyquist frequency
        numTaps, alpha = kaiserord((transitionWidth*2)/srate, attenuation)
        # Make sure the number of taps is odd
        numTaps |= 1
        @info numTaps, alpha, transitionWidth, attenuation
        return FIRWindow(kaiser(numTaps, alpha))        
    else
        if attenuation != 53
            error("Attenuation value only supported for Kaiser and Remez methods.")
        end
        numTaps = filterord(window, transitionWidth/srate)
        return FIRWindow(eval(:($window($numTaps))))
    end
end

function design_filter(highPass, lowPass, srate, window, transitionWidth, passErr, stopErr)
    fType = choose_type(highPass, lowPass, srate)
    
    if window == :remez
        # Convert from dB to linear
        passErr = (1 - 10^(-passErr/20))
        stopErr = 10^(-stopErr/20)

        if length(transitionWidth) == 2
            @warn "Different transition widths might lead to overshooting and a faulty filter."
            minTrans = min(transitionWidth...)
            tVal = [transitionWidth[1]/2, transitionWidth[2]/2]
        else
            minTrans = transitionWidth
            tVal = [transitionWidth/2, transitionWidth/2]
        end

        # Estimate the order of the filter
        numTaps = remezord(1/srate, (minTrans+1)/srate, passErr, stopErr)
        # Make sure the number of taps is odd
        numTaps |= 1
        
        if typeof(fType) == Highpass{Float64}
            freqVec = [0, highPass - tVal[1], highPass + tVal[1], srate/2]
            gainVec = [0, 1]
            dFilter = remez(numTaps, freqVec, gainVec, weight=[1/stopErr, 1/passErr], Hz=srate)
        elseif typeof(fType) == Lowpass{Float64}
            freqVec = [0, lowPass - tVal[1], lowPass + tVal[1], srate/2]
            gainVec = [1, 0]
            dFilter = remez(numTaps, freqVec, gainVec, weight=[1/passErr, 1/stopErr], Hz=srate)
        elseif typeof(fType) == Bandpass{Float64}
            freqVec = [0, highPass - tVal[1], highPass + tVal[1], lowPass - tVal[2], lowPass + tVal[2], srate/2]
            gainVec = [0, 1, 0]
            dFilter = remez(numTaps, freqVec, gainVec, weight=[1/stopErr, 1/passErr, 1/stopErr], Hz=srate)
        elseif typeof(fType) == Bandstop{Float64}
            freqVec = [0, lowPass - tVal[1], lowPass + tVal[1], highPass - tVal[2], highPass + tVal[2], srate/2]
            gainVec = [1, 0, 1]
            dFilter = remez(numTaps, freqVec, gainVec, weight=[1/passErr, 1/stopErr, 1/passErr], Hz=srate)
        end
    else
        if length(transitionWidth) == 2
            if typeof(fType) == Bandpass{Float64}
                seq = [Lowpass, Lowpass]
            elseif typeof(fType) == Bandstop{Float64}
                seq = [Lowpass, Highpass]
            else
                error("Transition width must be a single value for highpass or lowpass filters.")
            end

            wins = [estimate_window(window, srate, x, stopErr) for x in transitionWidth]
            fLength = length.([wins[1].window, wins[2].window])
            dFilter = zeros(max(fLength...))
            
            diff = div(abs(fLength[1] - fLength[2]), 2)
            fLength[1] > fLength[2] ? offset = [0, diff] : offset = [diff, 0]

            @info fLength, diff

            # lower bound
            lType = seq[1](fType.w1, fs=2)
            dFilter[1+offset[1]:end-offset[1]] += digitalfilter(lType, wins[1])
            # upper bound
            uType = seq[2](fType.w2, fs=2)
            dFilter[1+offset[2]:end-offset[2]] -= digitalfilter(uType, wins[2])
        else
            win = estimate_window(window, srate, transitionWidth, stopErr)
            dFilter = digitalfilter(fType, win)
        end
    end
    return dFilter
end

function filter_data(raw::Raw; highPass=0, lowPass=0, window=:kaiser)
    output = deepcopy(raw)
    output.chans, output.data = filter_data!(raw.data. raw.chans; highPass=highPass, lowPass=lowPass, window=window)
    return output
end

function filter_data!(raw::Raw; highPass=0, lowPass=0, window=:kaiser)
    filter_data!(raw.data. raw.chans; highPass=highPass, lowPass=lowPass, window=window)
end

function filter_data!(data::Matrix, chans::Channels; highPass=0, lowPass=0, window=:kaiser, transition=:auto, passErr=:auto, stopErr=:auto)
    srate = chans.srate[1]

    if transition == :auto
        transitionWidth = estimate_transition(highPass, lowPass, srate)
    elseif (highPass != 0) && (highPass - transition < 0)
        error("Transition width cannot be larger than highpass value.")
    elseif (lowPass != 0) && (lowPass + transition > srate/2)
        error("Transition width cannot go beyond Nyquist frequency of $(srate/2)Hz.")
    else
        transitionWidth = transition
    end
    
    # Set default values close to Hamming window parameters in dB
    if passErr == :auto
        passErr = 0.02
    elseif !(typeof(passErr) <: Number)
        error("Passband ripple must be a number.")
    end

    if stopErr == :auto
        stopErr = 53
    elseif !(typeof(stopErr) <: Number)
        error("Stopband attenuation must be a number.")
    end

    digFilter = design_filter(highPass, lowPass, srate, window, transitionWidth, passErr, stopErr)
    @info length(digFilter)

    apply_filter!(data, digFilter)
    update_filter_info!(chans, highPass, lowPass)
end

function apply_filter!(data::Matrix, digFilter)
    Threads.@threads for chan in axes(data, 2)
        @inbounds @views data[:, chan] = filtfilt(digFilter, data[:, chan])
    end
end

function update_filter_info!(chans::Channels, highPass::Integer, lowPass::Integer)
    for chan in chans
        chan.filters["highPass"] = highPass
        chan.filters["lowPass"] = lowPass
    end
end

