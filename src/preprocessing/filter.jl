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
    return winLength % 2 == 0 ? winLength + 1 : winLength
end

function estimate_window(window::Symbol, transitionWidth::Number, attenuation::Number=53) 
    if window == :kaiser
        # Kaiserord expects transition relative to Nyquist frequency
        numTaps = kaiserord(transitionWidth*2, attenuation)
        return FIRWindow(kaiser(numTaps...))
    elseif window == :remez
        error("Remez window not supported yet.")
    else
        if attenuation != 53
            error("Attenuation value only supported for Kaiser and Remez methods.")
        end
        numTaps = filterord(window, transitionWidth)
        return FIRWindow(eval(:($window($numTaps))))
    end
end

function filter_data(raw::Raw; highPass=0, lowPass=0, window=:kaiser)
    output = deepcopy(raw)
    output.chans, output.data = filter_data!(raw.data. raw.chans; highPass=highPass, lowPass=lowPass, window=window)
    return output
end

function filter_data!(raw::Raw; highPass=0, lowPass=0, window=:kaiser)
    filter_data!(raw.data. raw.chans; highPass=highPass, lowPass=lowPass, window=window)
end

function filter_data!(data::Matrix, chans::Channels; highPass=0, lowPass=0, window=:kaiser, transition=:auto)
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

    
    fType = choose_type(highPass, lowPass, srate)
    win = estimate_window(window, transitionWidth)

    digFilter = digitalfilter(fType, win)
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

