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
        `events::Vector`
            Vector of tuples containing timepoint and label pairs marking events in data.
        `status::Dict`
            Dictionary of values extracted from the Status channel of BioSemi .bdf files.
"""
mutable struct Raw{T} <: Recording where T
    info::Info{T}
    chans::Channels
    data::Array
    times::StepRangeLen
    events::Vector
    status::Dict
end

Raw(filename::String, name, srate, data) = Raw(
    Info(filename),
    Channels(name, srate),
    data,
    0:(1/srate):(length(data)/srate),
    Vector[], Dict())

Base.length(raw::Raw) = size(raw.data)[1]