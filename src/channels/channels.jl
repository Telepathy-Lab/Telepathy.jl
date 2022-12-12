function channel_names(file::Raw)
    return file.chans.name
end

function get_channels(data, names::Vector{String})
    return indexin(names, data.chans.name)
end

function get_channels(data, names::String)
    return indexin([names], data.chans.name)
end