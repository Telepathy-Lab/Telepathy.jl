abstract type FileType end

struct BDF <: FileType end
struct BVF <: FileType end

Base.show(io::IO, ::Type{BDF}) = print(io, "BDF")
Base.show(io::IO, ::Type{BVF}) = print(io, "BVF")

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
    Telepathy.Sensor

    Abstract type grouping different kinds of possible sensors in a recording.
    Currently, Telepathy recognizes the following: EEG, EOG, EMG, ECG, SIG, MISC, and STIM.

    While most is self-explanatory, it is worth noting that SIG is a generic type for all
    sensors that should be treated as biological signals. This will assume they are periodic
    in nature and will be processed accordingly (similarly to e.g. EEG).
    MISC on the other hand is a generic type for non-periodic signals. Channels with this
    type will be treated as digital (similarly to STIM).
"""
abstract type Sensor end

struct EEG <: Sensor end
struct EOG <: Sensor end
struct EMG <: Sensor end
struct ECG <: Sensor end
struct SIG <: Sensor end
struct MISC <: Sensor end
struct STIM <: Sensor end

Base.show(io::IO, sensor::EEG) = print(io, :EEG)
Base.show(io::IO, ::Type{EEG}) = print(io, :EEG)

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
    type::Vector{Sensor}
    location::Layout
    srate::Vector{Real}
    filters::Vector{Dict}
end

Channels(name, srate) = Channels(name, fill(EEG(), length(name)), EmptyLayout(), srate, Dict[])
Channels(name, srate::Real) = Channels(name, fill(EEG(), length(name)), EmptyLayout(), 
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
Base.length(raw::Raw) = size(raw.data, 2)
Base.size(raw::Raw) = size(raw.data, 2)

# Requirements for indexing Raw as an array Raw.data
Base.getindex(raw::Raw, indices...) = raw.data[get_data(raw, indices...)...]
Base.setindex!(raw::Raw, v, indices...) = Base.setindex!(raw.data, v, get_data(raw, indices...)...)

# Commented out first and last index until decided if we want to support `begin` and `end`
# syntax, as it would require changes in get_data - e.g. fixed order of selectors.
#Base.firstindex(raw::Raw) = Base.firstindex(raw.data)
#Base.lastindex(raw::Raw) = Base.lastindex(raw.data)
Base.iterate(raw::Raw, n=1) = n > length(raw) ? nothing : (raw.data[:,n], n+1)
Base.IndexStyle(raw::Raw) = IndexLinear()

Base.axes(raw::Raw) = Base.axes(raw.data)
Base.axes(raw::Raw, d) = Base.axes(raw.data, d)
Base.view(raw::Raw, indices...) = Base.view(raw.data, get_data(raw, indices...)...)
Base.maybeview(raw::Raw, indices...) = Base.maybeview(raw.data, get_data(raw, indices...)...)
