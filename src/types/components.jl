abstract type Layout end

struct EmptyLayout <: Layout end

mutable struct Spherical <: Layout
    name::String
    label::Vector{String}
    theta::Vector{Float64}
    phi::Vector{Float64}
end

mutable struct Cartesian <: Layout
    name::String
    label::Vector{String}
    x::Vector{Float64}
    y::Vector{Float64}
    z::Vector{Float64}
end

mutable struct Geographic <: Layout
    name::String
    label::Vector{String}
    theta::Vector{Float64}
    phi::Vector{Float64}
end

Layout(name::String, label::Vector{String}, x::Vector{Float64}, y::Vector{Float64}, z::Vector{Float64}) = Cartesian(name, label, x, y, z)

function Layout(name::String, label::Vector{String}, theta::Vector{Float64}, phi::Vector{Float64})
    if findfirst(x -> x < -120, theta) === nothing
        Spherical(name, label, theta, phi)
    else
        Geographic(name, label, theta, phi)
    end
end


# Conversions from one layout to another, based on Biosemi layouts:
# https://www.biosemi.com/download/Cap_coords_all.xls
# and Wikipedia page:
# http://en.wikipedia.org/wiki/Spherical_coordinate_system

# TODO: Add aliases and approximate channels to Biosemi layouts.

function Spherical(layout::Spherical)
    @info "Layout already in Spherical coordiantes."
    layout
end

function Spherical(layout::Cartesian)
    circumference = 55
    r = circumference/2π * 10 #conversion to milimeters
    theta = zeros(Float64, length(layout.label))
    phi = similar(theta)

    for i in eachindex(layout.label)
        if (layout.x[i] == NaN) & (layout.y[i] == NaN) & (layout.z[i] == NaN)
            theta[i] = NaN
            phi[i] = NaN
        else
            theta[i] = round(atand(sqrt(layout.x[i]^2 + layout.y[i]^2),layout.z[i]))
            if layout.x[i] < 0
                theta[i] *= -1
            end
            phi[i] = round(atand(layout.y[i]/layout.x[i]))

            #Correct the undefined calculation for Cz.
            if layout.label[i] == "Cz"
                phi[i] = 0
            end
        end
    end
    Spherical(layout.name, layout.label, theta, phi)
end

function Spherical(layout::Geographic)
    theta = zeros(Float64, length(layout.label))
    phi = similar(theta)

    for i in eachindex(layout.label)
        if (layout.theta[i] == NaN) & (layout.phi[i] == NaN)
            theta[i] = NaN
            phi[i] = NaN
        else
            layout.theta[i] <= 0 ? theta[i] = 90 - layout.phi[i] : theta[i] = layout.phi[i] - 90
            layout.theta[i] <= 0 ? phi[i] = 90 + layout.theta[i] : phi[i] = layout.theta[i] - 90
        end
    end
    Spherical(layout.name, layout.label, theta, phi)
end

function Cartesian(layout::Cartesian)
    @info "Layout already in Cartesian coordiantes."
    layout
end

function Cartesian(layout::Spherical)
    circumference = 55
    r = circumference/2π * 10 #conversion to milimeters
    x = zeros(Int64, length(layout.label))
    y = similar(x)
    z = similar(x)

    for i in eachindex(layout.label)
        if (layout.theta[i] == NaN) & (layout.phi[i] == NaN)
            x[i] = NaN
            y[i] = NaN
            z[i] = NaN
        else
            x[i] = round(r*sin(deg2rad(layout.theta[i]))*cos(deg2rad(layout.phi[i])))
            y[i] = round(r*sin(deg2rad(layout.theta[i]))*sin(deg2rad(layout.phi[i])))
            z[i] = round(r*cos(deg2rad(layout.theta[i])))
        end
    end
    Cartesian(layout.name, layout.label, x, y, z)
end

function Cartesian(layout::Geographic)
    Cartesian(Spherical(layout))
end

function Geographic(layout::Geographic)
    @info "Layout already in Geographic coordiantes."
    layout
end

function Geographic(layout::Spherical)
    theta = zeros(Float64, length(layout.label))
    phi = similar(theta)

    for i in eachindex(layout.label)
        if (layout.theta[i] == NaN) & (layout.phi[i] == NaN)
            theta[i] = NaN
            phi[i] = NaN
        else
            layout.theta[i] < 0 ? theta[i] = layout.phi[i] + 90 : theta[i] = layout.phi[i] - 90
            layout.theta[i] < 0 ? phi[i] = 90 + layout.theta[i] : phi[i] = 90 - layout.theta[i]
        end
    end
    Geographic(layout.name, layout.label, theta, phi)
end

function Geographic(layout::Cartesian)
    Geographic(Spherical(layout))
end