set_layout!(raw::Raw, layout::Symbol) = set_layout!(raw::Raw, joinpath(@__DIR__, "locations", "$(string(layout)).lay"), layout)

function set_layout!(raw::Raw, file::String, laySym::Symbol)
    layout = read_layout(file, laySym)

    matchCounter = 0
    missList = Vector{String}()
    layoutTemp = Array{Float64}(undef,length(raw.chans.name),2)
    for (idx, chan) in enumerate(raw.chans.name)
        if chan in layout.label
            lidx = findfirst(x->x==chan, layout.label)
            layoutTemp[idx,1] = layout.theta[lidx]
            layoutTemp[idx,2] = layout.phi[lidx]
            matchCounter += 1
        else
            layoutTemp[idx,1] = NaN
            layoutTemp[idx,2] = NaN
            push!(missList, chan)
        end
    end

    raw.chans.location = Layout(string(laySym), raw.chans.name, layoutTemp[:,1], layoutTemp[:,2])

    if !isempty(missList)
        missed = "No location data for these channels $missList"
    else
        missed = ""
    end
    @info """
    Locations found for $matchCounter channels.
    \t$missed
    """
end

read_layout(layout::Symbol) = read_layout(joinpath(@__DIR__, "locations", "$(string(layout)).lay"), layout)

function read_layout(file::String, layout::Symbol)
    if isfile(file)
        locs, header = readdlm(file, header=true)
        locations = Dict(header[i] => locs[:,i] for i in eachindex(header))
        return Spherical(string(layout), locations["label"], locations["theta"], locations["phi"])
    else
        error("Can't find the file $file. Please check the if the path is correct.")
    end
end

function convert_layout!(coordType::Symbol, raw::Raw)
    raw.chans.location = eval(Expr(:call, coordType, raw.chans.location))
end

valid_locations(layout::Spherical) = count(!isnan, layout.theta)
valid_locations(layout::Cartesian) = count(!isnan, layout.x)
valid_locations(layout::Geographic) = count(!isnan, layout.theta)