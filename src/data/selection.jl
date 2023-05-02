# SELECT DATA BASED ON TIME IN SECONDS
# TODO: Add info in docs that using floats needs to specify the step fine enough to get the desired decimal places
_get_times(rec::Recording, times::AbstractFloat) = _get_times(rec, times-1:times)

_get_times(rec::Recording, times::Colon) = 1:size(rec.data, 1)

# Convert to range to not loose precision
_get_times(rec::Recording, start::AbstractFloat, stop::AbstractFloat; kwargs...) = _get_times(rec, start:(1/rec.chans.srate[1]):stop; kwargs...)
_get_times(rec::Recording, times::Tuple{<:T, <:T}; kwargs...) where T <: AbstractFloat = _get_times(rec, times[1], times[2]; kwargs...)

function _get_times(raw::Raw, times::StepRangeLen; anchor::Number=0)
    # Check if range is not empty
    if times.len == 1 
        @warn """Time range contains only one point. 
        In Julia, default step is 1, so you need to specify a smaller step 
        to get ranges with distance different than a whole number, e.g. 0.2:0.1:0.7."""
    end

    # Check if anchor is an integer or float
    if typeof(anchor) <: AbstractFloat
        anchor = round(Int64, anchor*get_srate(raw))
    elseif !(typeof(anchor) <: Integer)
        error("Anchor must be an integer or float.")
    end

    start = round(Int64, times[begin]*get_srate(raw) + 1 + anchor)
    finish = round(Int64, times[end]*get_srate(raw) + 1 + anchor)
    return UnitRange(start, finish)
end

function offset_time(epochs::Epochs, time::AbstractFloat) 
    return findfirst(x -> isapprox(x, time, atol=1/(epochs.chans.srate[1]*2)), epochs.times)
end

function _get_times(epochs::Epochs, times::StepRangeLen; anchor::Number=0.)
    # Check if range is not empty
    if times.len == 1 
        @warn """Time range contains only one point. 
        In Julia, default step is 1, so you need to specify a smaller step 
        to get ranges with distance different than a whole number, e.g. 0.2:0.1:0.7."""
    end

    # Check if anchor is an integer or float
    if typeof(anchor) <: Integer
        anchor = epochs.times[anchor]
    elseif typeof(anchor) <: AbstractFloat
        if anchor != 0.
            epochs.times[begin] <= anchor <= epochs.times[end] || error("Anchor is outside of the epoch range.")
        end
    else
        error("Anchor must be an integer or float.")
    end

    start = offset_time(epochs, times[begin] + anchor)
    finish = offset_time(epochs, times[end] + anchor)

    isnothing(start) && error("Selection start is outside of the epoch range.")
    isnothing(finish) && error("Selection end is outside of the epoch range.")
    return UnitRange(start, finish)
end

# SELECT DATA BASED ON CHANNEL NAMES, TYPES OR INDICES
# Generic versions for use without EEG objects
_get_channels(data::AbstractArray, chanID::Integer) = _get_channels(data, chanID:chanID)
_get_channels(data::AbstractArray, chanRange::UnitRange) = collect(intersect(1:size(data, 2), chanRange))

# Selection based on integer indices
_get_channels(rec::Recording, chanID::Integer) = _get_channels(rec, chanID:chanID) 
_get_channels(rec::Recording, chanRange::UnitRange) = collect(intersect(1:length(rec.chans.name), chanRange))
_get_channels(rec::Recording, chanRange::AbstractVector{<:Integer}) = intersect(chanRange, 1:length(rec.chans.name))

# Selection based on string channel names
# Selecting the first element make the slicing return a Vector rather than a Matrix
function _get_channels(rec::Recording, name::String)
    idx = _get_channels(rec, [name])
    if isempty(idx)
        error("Channel $name not found in data.")
    else
        return idx[1]
    end
end

function _get_channels(rec, names::Vector{String})
    return findall(x -> x in names, rec.chans.name)
end

function _get_channels(rec, regex::Regex)
    return (1:length(rec.chans.name))[occursin.(regex, rec.chans.name)]
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


# SELECT DATA BASED ON SEGMENT INDICES OR EVENTS
# Selection of data segments, if they exist
_get_segments(raw::Raw, args...) = 1
_get_segments(epochs::Epochs) = _get_segments(epochs::Epochs, colon::Colon)
_get_segments(epochs::Epochs, colon::Colon) = 1:size(epochs.data, 3)
_get_segments(epochs::Epochs, segment::Integer) = _get_segments(epochs::Epochs, [segment])
_get_segments(epochs::Epochs, segments::AbstractVector{<:Integer}) = intersect(segments, 1:size(epochs.data, 3))


# PUBLIC INTERFACE FOR DATA SELECTION
function select(rec::Recording; times=0, channels=0, segments=0, indices=false, anchor=0.)

    times != 0 ? times = _get_times(rec, times, anchor=anchor) : times = _get_times(rec, :)
    channels != 0 ? channels = _get_channels(rec, channels) : channels = _get_channels(rec, :)
    segments != 0 ? segments = _get_segments(rec, segments) : segments = _get_segments(rec, :)

    if indices
        return times, channels, segments
    else
        return rec.data[times, channels, segments]
    end
end