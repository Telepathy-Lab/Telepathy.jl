function channel_names(rec::Recording)
    return rec.chans.name
end

get_channels(rec::Recording, chans) = get_data(rec, :, chans)

# Generic versions for use without EEG objects
_get_channels(data::AbstractArray, chanID::Integer) = _get_channels(data, chanID:chanID)
_get_channels(data::AbstractArray, chanRange::UnitRange) = _collect(intersect(1:size(data, 2), chanRange))

# Selection based on integer indices
_get_channels(rec::Recording, chanID::Integer) = _get_channels(rec, chanID:chanID) 
_get_channels(rec::Recording, chanRange::UnitRange) = collect(intersect(1:length(rec.chans.name), chanRange))
_get_channels(rec::Recording, chanRange::AbstractVector{<:Integer}) = intersect(chanRange, 1:length(rec.chans.name))

# Selection based on string channel names
# Selecting the first element make the slicing return a Vector rather than a Matrix
function _get_channels(rec::Recording, name::String)
    idx = get_channels(rec, [name])
    if isempty(idx)
        error("Channel $name not found in data.")
    else
        return idx[1]
    end
end

function _get_channels(rec, names::Vector{String})
    return findall(x -> x in names, rec.chans.name)
end

# Selection based on symbol channel type
_get_channels(rec::Recording, type::Symbol) = _get_channels(rec, [type])
function _get_channels(rec, types::Vector{Symbol})
    # We only eval the types, no function calls are made, so hopefully this reduces side effects
    types = [eval(:(Telepathy.$type)) for type in types]
    return findall(x -> typeof(x) in types, rec.chans.type)
end

# Selection based on direct channel type
function _get_channels(rec::Recording, type::Sensor)
    return findall(x -> x==type, rec.chans.type)
end
_get_channels(rec::Recording, channels::Colon) = 1:size(rec.data, 2)


get_times(rec::Recording, times) = get_data(rec, times, :)

# TODO: Add info in docs that using floats needs to specify the step fine enough to get the desired decimal places
_get_times(raw::Raw, times::AbstractFloat) = _get_times(raw, times-1:times)

function _get_times(raw::Raw, times::AbstractRange; anchor::Number=0)
    if typeof(anchor) <: AbstractFloat
        anchor = round(Int64, anchor*get_srate(raw))
    elseif !(typeof(anchor) <: Integer)
        error("Anchor must be an integer or float.")
    end

    start = round(Int64, times[begin]*get_srate(raw) + 1 + anchor)
    finish = round(Int64, times[end]*get_srate(raw) + anchor)
    return UnitRange(start, finish)
end

_get_times(raw::Raw, times::Colon) = 1:size(raw.data, 1)

# Convert to range to not loose precision
_get_times(raw::Raw, start::AbstractFloat, stop::AbstractFloat; kwargs...) = _get_times(raw, start:(stop-start):stop; kwargs...)

# Selection of data segments, if they exist
get_segments(raw::Raw) = 1:1
get_segments(epochs::Epochs) = 1:size(epochs.data, 3)

# Separate type unions for times and channel selectors to check for input order in get_data
rowTypes = Union{AbstractFloat, AbstractRange{<:AbstractFloat}}
colTypes = Union{AbstractString, Symbol, Sensor, Integer,
                 AbstractVector{<:Union{AbstractString, Symbol, Sensor, Integer}}}

get_data(rec::Recording, times, chans) = rec.data[_get_data(rec, times, chans)...]

# We are covering both orders of selector inputs for convenience
_get_data(raw::Raw, first::Colon) = error("Ambigous selection, please specify both times and channels.")
_get_data(raw::Raw, first::rowTypes) = _get_data(raw, first, :)
_get_data(raw::Raw, first::colTypes) = _get_data(raw, :, first)
_get_data(raw::Raw, first::colTypes, second::rowTypes) = _get_data(raw, second, first)
_get_data(raw::Raw, first::Colon, second::Colon) = (first, second)
_get_data(raw::Raw, first, second::Colon) = typeof(first) <: rowTypes ? (_get_times(raw, first), second) : (second, _get_channels(raw, first))
_get_data(raw::Raw, first::Colon, second) = typeof(second) <: rowTypes ? (_get_times(raw, second), first) : (first, _get_channels(raw, second))
function _get_data(raw::Raw, first::rowTypes, second::colTypes)
    return _get_times(raw, first), _get_channels(raw, second)
end

set_type!(data, chans, type::Symbol) = set_type!(data, chans, eval(:(Telepathy.$type)))
set_type!(data, chans, type::Type{<:Sensor}) = set_type!(data, chans, type())
function set_type!(data, chans, type::Sensor)
    chanIDs = get_channels(data, chans)
    for i in chanIDs
        data.chans.type[i] = type
    end
    @info "Channels $(data.chans.name[chanIDs]) changed to type $type"
end

# TODO: Needs to change when we add support for multiple sampling rates or unify reads
get_srate(rec::Recording) = convert(Float64, rec.chans.srate[1])