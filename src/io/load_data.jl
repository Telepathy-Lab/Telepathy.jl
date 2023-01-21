# TODO: Add passing kwargs to EEGIO functions
# TODO: Allow to specify the type of channel on load (e.g. EEG, ECoG, etc.)

function load_data(file::String)
    println("Loading data from $file")
    format = recognize_format(file)
    println("Calling subroutine to load the file type.")
    return format(file)
end

function recognize_format(file::String)
    extension = splitext(abspath(file))[2]

    format_list = Dict(
        ".bdf" => read_from_bdf,
        ".eeg" => read_eeg,
        ".vhdr" => read_eeg,
        ".vmrk" => read_eeg,
    )

    try
        return format_list[extension]
    catch
        @error "Unknown file format: $extension"
    end
end

function read_from_bdf(file)

    hdr = Info(file)
    chns = Channels([""], 0)

    open(file) do fid
        header = EEGIO.read_bdf_header(fid)

        hdr.participantID = header.subID
        hdr.recordingID = header.recID
        hdr.date = header.startDate
        hdr.history = [""]

        names = Vector{String}(undef, header.nChannels)
        types = Vector{Sensor}(undef, header.nChannels)
        locations = EmptyLayout()
        srate = Vector{Real}(undef, header.nChannels)
        filters = Vector{Dict}(undef, header.nChannels)
        reference = Vector{String}(undef, header.nChannels)

        for i in eachindex(header.chanLabels)
            names[i] = header.chanLabels[i]
            types[i] = parse_electrode_type(header.transducer[i])
            srate[i] = Int32(header.nSampRec[i] / header.recordDuration)
            filters[i] = Dict("filt" => header.prefilt[i])
        end
        chns.name = names
        chns.type = types
        chns.location = locations
        chns.srate = srate
        chns.filters = filters
        chns.reference = reference

        data = EEGIO.read_bdf_data(fid, header, true, Float32, :All, :None, :All, true)

        times = 0:(1/srate[1]):(length(data)/srate[1])
        status = Dict(
            "lowTrigger" => UInt8[0],
            "highTrigger" => UInt8[0],
            "status" => UInt8[0],
        )
        return Raw(hdr, chns, data, times, Array{Int64}[], status)
    end
end

function parse_electrode_type(transducer::String)
    if occursin("Active", transducer)
        return EEG()
    elseif occursin("Status", transducer)
        return STIM()
    else
        return MISC()
    end
end

function parse_status!(raw::Raw{BDF})
    idx = get_channels(raw, "Status")
    if length(idx) == 1
        raw.status["lowTrigger"], raw.status["highTrigger"], raw.status["status"] = parse_status(raw.data[:,idx[1]])
    elseif length(idx) == 0
        error("No Status channel in data.")
    else
        error("Multiple channels named Status in data.")
    end
end

function parse_status(data::Vector)
    a = Int32.(data[:,end])
    triggerLow = Vector{UInt8}(undef, length(a))
    triggerHigh = Vector{UInt8}(undef, length(a))
    status = Vector{UInt8}(undef, length(a))

    for sample in eachindex(a)
        triggerLow[sample] = (a[sample]>>((1-1)<<3))%UInt8
        triggerHigh[sample] = (a[sample]>>((2-1)<<3))%UInt8
        status[sample] = (a[sample]>>((3-1)<<3))%UInt8
    end
    return triggerLow, triggerHigh, status
end