function default_transition(highPass, lowPass, srate)
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

"""
    Telepathy.estimate_transition(highPass, lowPass, srate)

Estimate the width of the transition band for a filter, if not provided. Follows the suggestions
from Widmann et al. (2015).
"""
function estimate_transition(highPass, lowPass, transition, srate)

    if transition == :auto
        default_transition(highPass, lowPass, srate)
    elseif (highPass != 0) && (highPass - transition < 0)
        error("Transition width cannot be larger than the highpass value.")
    elseif (lowPass != 0) && (lowPass + transition > srate/2)
        error("Transition width cannot go beyond Nyquist frequency of $(srate/2)Hz.")
    else
        return transition
    end
end

function estimate_transition(highPass, lowPass, transition::Vector, srate)
    tSize = length(transition)
    if tSize == 1
        estimate_transition(highPass, lowPass, transition[1], srate)
    elseif tSize == 2
        hTrans = estimate_transition(highPass, 0, transition[1], srate)
        lTrans = estimate_transition(0, lowPass, transition[2], srate)
        return [hTrans, lTrans]
    else
        error("Transition width must be a scalar or a vector of length 2.")
    end
end

mutable struct FilterDetails
    transition::Float64
    pbripple::Float64
    ripple::Float64
    sidelobe::Integer
    attenuation::Integer
end

filterDetails = Dict(
    :rectangular    => FilterDetails(0.9, 0.741,  0.089,    -13, 21),
    :hann           => FilterDetails(3.1, 0.0546, 0.063,    -31, 44),
    :hanning        => FilterDetails(3.1, 0.0546, 0.063,    -31, 44),
    :hamming        => FilterDetails(3.3, 0.0194, 0.0022,   -41, 53),
    :blackman       => FilterDetails(5.5, 0.0017, 0.000196, -57, 74),
)

function estimate_error(passErr, stopErr)
    if passErr == :auto
        passErr = filterDetails[:hamming].pbripple
    elseif !(typeof(passErr) <: Number)
        error("Passband ripple must be a number.")
    end

    if stopErr == :auto
        stopErr = filterDetails[:hamming].attenuation
    elseif !(typeof(stopErr) <: Number)
        error("Stopband attenuation must be a number.")
    end
    return passErr, stopErr
end

"""
    Telepathy.estimate_type(highPass, lowPass, srate)

Matches the provided highpass and lowpass values to the appropriate filter type.
"""
function estimate_type(highPass::Number, lowPass::Number, srate::Number)
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

function design_remez(fType, highPass, lowPass, transitionWidth, passErr, stopErr, srate)
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
    return dFilter
end

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

function design_filter(fType, window, transitionWidth, passErr, stopErr, srate)
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
    return dFilter
end

# TODO: Add support for IIR filters
function design_filter(highPass, lowPass, srate, window, transition, passErr, stopErr)
    # Estimate the type of filter from the provided values
    fType = estimate_type(highPass, lowPass, srate)
    
    # Estimate the transition widths from provided parameters
    transitionWidth = estimate_transition(highPass, lowPass, transition, srate)
    
    # Set default values close to Hamming window parameters in dB
    passErr, stopErr = estimate_error(passErr, stopErr)

    # Construct the filter based on the window chosen
    if window == :remez
        dFilter = design_remez(fType, highPass, lowPass, transitionWidth, passErr, stopErr, srate)
    else
        dFilter = design_filter(fType, window, transitionWidth, passErr, stopErr, srate)
    end
    return dFilter
end


function update_filter_info!(raw::Raw, chans::Vector, highPass::Number, lowPass::Number)
    for chan in chans
        raw.chans.filters[chan]["Highpass"] = highPass
        raw.chans.filters[chan]["Lowpass"] = lowPass
    end
end

function create_buffers(dataLength, srate, filterLength, nThreads)
    # Pad data with a multiple of sampling rate bigger than 1.5 times the filter length,
    # but not smaller than 2.
    srate = round(Int, srate)
    multiple = max(cld(filterLength, srate), 2)
    padding = multiple * srate
    input = [zeros(dataLength + 2*padding) for i in 1:nThreads]
    output = [zeros(dataLength + 2*padding) for i in 1:nThreads]
    return input, output, padding
end

function filter_channel(data, input, output, digFilter, padding)
    # Copy data to buffer
    @views begin
        input[1:padding] .= data[padding:-1:1]
        input[padding+1:padding+length(data)] .= data
        input[padding+length(data)+1:end] .= data[end:-1:end-padding+1]
    end
    offset = padding + div(length(digFilter)+1, 2)

    # Filter the data
    filt!(output, digFilter, input)
    return view(output, offset:offset+length(data)-1)
end

function filter_data!(data::Matrix, digFilter, chans, srate, nThreads)
    input, output, padding = create_buffers(size(data, 1), srate, length(digFilter), nThreads)
    #@info length(input[1]), padding
    Threads.@threads for (thrID, batch) in setup_workers(chans, nThreads)
        for chan in batch
            @debug thrID, chan
            @views data[:, chan] = filter_channel(data[:, chan], input[thrID], output[thrID], digFilter, padding)
        end
    end
end

# TODO: Adding option for filtfilt?
function filter_data!(raw::Raw; highPass=0, lowPass=0, 
                    window=:kaiser, transition=:auto, passErr=:auto, stopErr=:auto,
                    nThreads=options.nThreads)

    srate = get_srate(raw)

    # Design the filter
    digFilter = design_filter(highPass, lowPass, srate, window, transition, passErr, stopErr)

    # Apply the filter to EEG channels
    chans = get_channels(raw, :EEG)
    filter_data!(raw.data, digFilter, chans, srate, nThreads)

    # Update the channel information
    update_filter_info!(raw, chans, highPass, lowPass)
end

function filter_data(raw::Raw; kwargs...)
    output = deepcopy(raw)
    filter_data!(output; kwargs...)
    return output
end
