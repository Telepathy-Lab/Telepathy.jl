# Generate an iterable that will allow to go through the data in specified segments
function calculate_segments(data::Raw, timeSpan::Number; overlap=0)
    nSamples, nChannels = size(data.data)
    sRate = get_srate(data)

    # If the timeSpan is 0, we return the whole data
    timeSpan==0 && return 1:1, nSamples
    
    offset = _get_sample(data, timeSpan-overlap)
    sampleSpan = _get_sample(data, timeSpan)

    startingPoints = 1:offset:cld(nSamples-sampleSpan, offset)*offset

    return startingPoints, sampleSpan
end

function aggregate(raw::Raw, func::Function; mode=:channels, timeSpan=0., channels=:, overlap=0., threads=0)

    # Get necessary indexes to slice the data into segments
    segmentStarts, segmentSize = calculate_segments(raw, timeSpan, overlap=overlap)

    # Aggregate either each channel separately or a whole segment
    if mode == :channels
        elements = _get_channels(raw, channels)
        @debug "Aggregating $(length(segmentStarts)) segments of $(length(elements)) channels."
    elseif mode == :segments
        elements = [_get_channels(raw, channels)]
        @debug "Aggregating $(length(segmentStarts)) segments reduced from $(length(elements[1])) channels."
    else
        error("Mode $mode not recognized.")
    end

    # Allocate memory for the aggregated data
    aggregatedData = zeros(length(segmentStarts), length(elements))

    Threads.@threads for (thrID, segmentIDs) in setup_workers(1:length(segmentStarts), threads)
        @debug "Thread $thrID processing segments $segmentIDs"
        for sID in segmentIDs
            for (j, element) in enumerate(elements)
                range = segmentStarts[sID]:segmentStarts[sID]+segmentSize-1
                @views aggregatedData[sID, j] = func(raw.data[range, element])
            end
        end
    end

    return aggregatedData
end

function aggregate(epochs::Epochs, func::Function; mode=:channels, timeSpan=0, channels=:, segments=0, overlap=0., threads=0)

    times, chans, segments = select(epochs, times=timeSpan, channels=channels, segments=segments, indices=true)

    # Aggregate either each channel separately or a whole segment
    if mode == :channels
        elements = chans
        @debug "Aggregating $(length(segments)) segments of $(length(elements)) channels."
    elseif mode == :segments
        elements = [chans]
        @debug "Aggregating $(length(segments)) segments reduced from $(length(elements[1])) channels."
    else
        error("Mode $mode not recognized.")
    end

    # Allocate memory for the aggregated data
    aggregatedData = zeros(length(segments), length(elements))

    Threads.@threads for (thrID, segmentIDs) in setup_workers(1:length(segments), threads)
        @debug "Thread $thrID processing segments $segmentIDs"
        for sID in segmentIDs
            for (j, element) in enumerate(elements)
                @views aggregatedData[sID, j] = func(epochs.data[times, element, sID])
            end
        end
    end

    return aggregatedData
end