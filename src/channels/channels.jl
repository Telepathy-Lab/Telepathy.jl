function channel_names(rec::Recording)
    return rec.chans.name
end




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