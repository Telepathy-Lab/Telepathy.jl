import Base: getindex, setindex!, axes, view, maybeview, firstindex, lastindex

abstract type FileType end

struct BDF <: FileType end
struct EEG <: FileType end

Base.show(io::IO, ::Type{BDF}) = print(io, "BDF")
Base.show(io::IO, ::Type{EEG}) = print(io, "EEG")

"""
    Telepathy.Info(filename::String)

    Object containing general information about the file.

    Fields:
        `filename::String`
            Name of the file. Necessary for saving data.
        `participantID::String`
            Individual identifier of the participant (optional).
        `recordingID::String`
            Individual indentifier of the recording (optional).
        `date`
            Date of the recording (optional).
        `history`
            List containg all operations performed in Telepathy on the data.
"""
mutable struct Info{T <: FileType}
    filename::String
    participantID::String
    recordingID::String
    date::String
    history::Vector{String}
end

Info(filename) = Info{eval(Symbol(uppercase(filename[end-2:end])))}(filename, "", "", "", String[])

"""
    Telepathy.Channels(name::Vector{String}, srate::Real)
    Telepathy.Channels(name::Vector{String}, srate::Vector{Real})


    Object containing channel-specific information. Arranged in the same order as columns
    in the data array.

    Fields
        `name::Vector{String}`
            List of names of channels in data.
        `type::Vector{String}`
            List of types of channels in data. Defaults to "EEG", unless declated otherwise.
            Currently Telepathy recognizes "EEG", "EOG", "EMG", and "MISC" types.
        `location::Array{Real}`
            Array containing locations of channels on the scalp (optional).
        `srate::Vector{Real}`
            Array of sampling rates of channels. Defaults to the same value for every channel
            unless declated otherwise.
        `filters::Vector{Dict}`
            Contains filters already applied to the channels. Defaults to the same values 
            for every channel unless declated otherwise.
"""
mutable struct Channels
    name::Vector{String}
    type::Vector{String}
    location::Array{Real}
    srate::Vector{Real}
    filters::Vector{Dict}
end

Channels(name, srate) = Channels(name, fill("EEG", length(names)), Array{Real}[], srate, Dict[])
Channels(name, srate::Real) = Channels(name, fill("EEG", length(name)), Array{Real}[], 
                                fill(srate, length(name)), Dict[])

"""
    Telepathy.Recording

    General parent type for different data containters in Telepathy.
    Currently includes only `Raw` type.
"""
abstract type Recording end

"""
    Raw(filename::String, name::Vector{String}, srate::Real, data::Array)
    
    Object containing continous signals.

    Fields:
        `info::Info`
            Object containing general information about a file.
        `chans::Channels`
            Object containing channel-specific information.
        `data::Array`
            Array with the signals in the same order as entries in Channels.
        `events::Array`
            Array of timepoint and label pairs marking events in data.
        `status::Dict`
            Dictionary of values extracted from the Status channel of BioSemi .bdf files.
"""
mutable struct Raw{T} <: Recording where T
    info::Info{T}
    chans::Channels
    data::Array
    times::StepRangeLen
    events::Array
    status::Dict
end

Raw(filename::String, name, srate, data) = Raw(
    Info(filename),
    Channels(name, srate),
    data,
    0:(1/srate):(length(data)/srate),
    Array[], Dict()
)

# Overloading some functions from Base to make Raw more workable
Base.length(raw::Raw) = size(raw.data, 1)

# Requires for indexing Raw as an array Raw.data
getindex(raw::Raw, indices...) = raw.data[indices...]
setindex!(raw::Raw, v, indices...) = setindex!(raw.data, v, indices...)
firstindex(raw::Raw) = firstindex(raw.data)
lastindex(raw::Raw) = lastindex(raw.data)
axes(raw::Raw) = axes(raw.data)
axes(raw::Raw, d) = axes(raw.data, d)
view(raw::Raw, indices...) = view(raw.data, indices...)
maybeview(raw::Raw, indices...) = maybeview(raw.data, indices...)

# Custom indexing using channel names
getindex(raw::Raw, channels::String) = getindex(raw, :, channels)
getindex(raw::Raw, channels::Vector{String}) = getindex(raw, :, channels)
getindex(raw::Raw, times::Float64) = getindex(raw, :, times)
getindex(raw::Raw, times::AbstractRange{Float64}) = getindex(raw, times, :)
getindex(raw::Raw, rows, columns) = raw.data[convert_inds(raw, rows), convert_inds(raw, columns)]

view(raw::Raw, channels::String) = view(raw, :, channels)
view(raw::Raw, channels::Vector{String}) = view(raw, :, channels)
view(raw::Raw, channels::Float64) = view(raw, channels, :)
view(raw::Raw, channels::AbstractRange{Float64}) = view(raw, channels, :)
view(raw::Raw, rows, columns) = view(raw.data, convert_inds(raw, rows), convert_inds(raw, columns))

maybeview(raw::Raw, channels::String) = maybeview(raw, :, channels)
maybeview(raw::Raw, channels::Vector{String}) = maybeview(raw, :, channels)
maybeview(raw::Raw, channels::Float64) = maybeview(raw, channels, :)
maybeview(raw::Raw, channels::AbstractRange{Float64}) = maybeview(raw, channels, :)
maybeview(raw::Raw, rows, columns) = maybeview(raw.data, convert_inds(raw, rows), convert_inds(raw, columns))

convert_inds(raw, values) = values
convert_inds(raw, channel::String) = findall(x -> x==channel, raw.chans.name)
convert_inds(raw, channels::Vector{String}) = indexin(channels, raw.chans.name)
convert_inds(raw, times::Float64) = frange_to_int(raw, times:times)
convert_inds(raw, times::AbstractRange{Float64}) = frange_to_int(raw, times)

function frange_to_int(raw::Raw, times::AbstractRange{Float64})
    start = Int64(times[begin]-1)*raw.chans.srate[begin] + 1
    finish = Int64(times[end])*raw.chans.srate[begin]
    return range(start, finish)
end