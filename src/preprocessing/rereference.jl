"""
    get_reference(raw::Raw; summary=false) -> Union{Matrix{Any}, Dict{Vector{String}, Int}}

Return the current reference for each channel in `raw`. If `summary` is `true`, return 
a `Dict` with the number of channels with each reference. Otherwise, return a `Matrix` 
with the channel name and the its current reference.

##### Arguments
- `raw::Raw`: Raw data object
- `summary::Bool`: If `true`, return a count of each reference type in data. Default is `false`.

##### Returns
- `Union{Matrix{Any}, Dict{Vector{String}, Int}}`: Current reference for each channel in `raw`.

##### Examples
```julia
# Get the current reference for each channel in raw
get_reference(raw)

# Get a summary of the current reference for each channel in raw
get_reference(raw, summary=true)
```
"""
function get_reference(raw::Raw; summary=false)
    if summary
        return countmap(raw.chans.reference)
    else
        return [raw.chans.name raw.chans.reference]
    end
end

"""
    set_reference(raw::Raw) -> Raw
    set_reference(raw::Raw, reference) -> Raw

Change the reference of the EEG data in `raw` and return it as a new object.
For a list of possible reference options, see [`set_reference!`](@ref).
"""
# Default to avergae reference
set_reference(raw::Raw) = set_reference(raw, :average)

# Generic case for everything that can be parsed by get_channels
function set_reference(raw::Raw, reference)
    new = deepcopy(raw)
    set_reference!(new, reference)
    return new
end

"""
    set_reference!(raw::Raw)
    set_reference!(raw::Raw, reference)

Change the reference of the EEG data in `raw`.
Current implementation only supports rereferencing all EEG channels at once. New reference
might be a single channel or an average of multiple channels. Calling the function without
specifying a reference will set the reference to the average of all EEG channels.
You can find information about the current reference for each channel under 
`raw.chans.reference` or by challing `get_reference(raw)`.

##### Arguments
- `raw::Raw`: Raw data object
- `reference::Union{Symbol, Integer, String, UnitRange, 
                    AbstractVector{<:Union{Symbol, Integer, String}}}`: Reference to use.
    Use `:average` to set the reference to the average of all EEG channels or `:none` to
    not change the reference. Otherwise, all arguments accepted by [`get_channels`](@ref)
    are valid.

##### Examples
```julia
# Set the reference to the average of all EEG channels
set_reference!(raw, :average)

# Set the reference to the average of channels 1, 2, and 3
set_reference!(raw, 1:3)

# Set the reference to the average of EOG channels
set_reference!(raw, :EOG)

# Set the reference to the average of channels Fp1 and Fp2 and return a new object
new = set_reference(raw, ["Fp1", "Fp2"])
```
"""
# Default to avergae reference
set_reference!(raw::Raw) = set_reference!(raw, :average)

# Generic case for everything that can be parsed by get_channels
set_reference!(raw::Raw, reference) = set_reference!(raw, get_channels(raw, reference))

# Resolve the average and none cases
function set_reference!(raw::Raw, reference::Symbol)
    if reference == :average
        set_reference!(raw, get_channels(raw, :EEG), case="average")
    elseif reference == :none
        return nothing
    else
        set_reference!(raw, get_channels(raw, reference), case=string(reference))
    end
end

# Main function working on the output from get_channels
function set_reference!(raw::Raw, reference::Vector{<:Integer}; case="")
    if length(reference) == 0
        error("No channels found for the requested reference.")
    elseif length(reference) == 1
        ref = raw.data[:,reference][:]
        case = [raw.chans.name[reference]]
    else
        # Compute the average
        ref = mean(raw.data[:, reference], dims=2)
        # Get the names of the channels going into the reference
        if case == ""
            case = raw.chans.name[reference]
        else
            case = [[case]]
        end
    end

    # Subtract the reference only from the EEG data
    channels = get_channels(raw, :EEG)
    #@views raw[:, channels] .-= ref
    rereference!(raw.data, ref, channels)
    # Vector of vectors is necessary even if we broadcast to inner vectors
    raw.chans.reference[channels] .= case
    
    return nothing
end

set_reference!(array::AbstractArray, reference) = set_reference!(array, get_channels(array, reference))

function set_reference!(array::AbstractArray, reference::Vector{<:Integer})
    if length(reference) == 0
        error("No channels found for the requested reference.")
    elseif length(reference) == 1
        ref = array[:,reference][:]
    else
        # Compute the average
        ref = mean(array[:, reference], dims=2)[:]
    end
    rereference!(array, ref, collect(1:size(array, 2)))
end

function rereference!(array::AbstractArray, reference::AbstractVector, channels)
    if size(array, 1) != length(reference)
        error("The number of rows in the array must match the length of the reference.")
    else
        @views array[:, channels] .-= reference
    end
end