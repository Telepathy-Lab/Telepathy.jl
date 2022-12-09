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
        types = Vector{String}(undef, header.nChannels)
        locations = Array{Real}(undef, (header.nChannels,3))
        srate = Vector{Real}(undef, header.nChannels)
        filters = Vector{Dict}(undef, header.nChannels)

        for i in eachindex(header.chanLabels)
            names[i] = header.chanLabels[i]
            types[i] = header.chanLabels[i] == "Status" ? "Stim" : "EEG"
            locations[i,:] = [0,0,0]
            srate[i] = Int32(header.nSampRec[i] / header.recordDuration)
            filters[i] = Dict("filt" => header.prefilt[i])
        end
        chns.name = names
        chns.type = types
        chns.location = locations
        chns.srate = srate
        chns.filters = filters

        data = EEGIO.read_bdf_data(fid, header, true, Float32, :All, :None, :All, true, false)

        return Raw(hdr, chns, data, [""])
    end
end