function channel_names(raw::Raw)
    return raw.chans.name
end

# Selection based on integer indices
get_channels(data::Raw, chanID::Integer) = get_channels(data, chanID:chanID) 
get_channels(data::Raw, chanRange::UnitRange) = collect(intersect(1:length(data.chans.name), chanRange))
get_channels(data::Raw, chanRange::AbstractVector{<:Integer}) = intersect(chanRange, 1:length(data.chans.name))

# Selection based on string channel names
# Selecting the first element make the slicing return a Vector rather than a Matrix
function get_channels(data::Raw, name::String)
    return get_channels(data, [name])[1]
end
function get_channels(data, names::Vector{String})
    return findall(x -> x in names, data.chans.name)
end

# Selection based on symbol channel type
get_channels(data::Raw, type::Symbol) = get_channels(data, [type])
function get_channels(data, types::Vector{Symbol})
    # We only eval the types, no function calls are made, so hopefully this reduces side effects
    types = [eval(:(Telepathy.$type)) for type in types]
    return findall(x -> typeof(x) in types, data.chans.type)
end

# Selection based on direct channel type
function get_channels(data::Raw, type::Sensor)
    return findall(x -> x==type, data.chans.type)
end
get_channels(raw::Raw, channels::Colon) = Colon()

# TODO: Add info in docs that using floats needs to specify the step fine enough to get the desired decimal places
get_times(raw::Raw, times::AbstractFloat) = times:times
function get_times(raw::Raw, times::AbstractRange)
    start = round(Int64, times[begin]*raw.chans.srate[begin] + 1)
    finish = round(Int64, times[end]*raw.chans.srate[begin])
    return range(start, finish)
end
get_times(raw::Raw, times::Colon) = Colon()

# Separate type unions for times and channel selectors to check for input order in get_data
rowTypes = Union{AbstractFloat, AbstractRange, Colon}
colTypes = Union{AbstractString, Symbol, Sensor, Integer,
                 AbstractVector{<:Union{AbstractString, Symbol, Sensor, Integer}}, Colon}

# We are covering both orders of selector inputs for convenience
get_data(raw::Raw, first::Colon) = error("Ambigous selection, please specify both times and channels.")
get_data(raw::Raw, first::rowTypes) = get_data(raw, first, :)
get_data(raw::Raw, first::colTypes) = get_data(raw, :, first)
get_data(raw::Raw, first::colTypes, second::rowTypes) = get_data(raw, second, first)
get_data(raw::Raw, first::Colon, second::Colon) = (first, second)
function get_data(raw::Raw, first::rowTypes, second::colTypes)
    return get_times(raw, first), get_channels(raw, second)
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

