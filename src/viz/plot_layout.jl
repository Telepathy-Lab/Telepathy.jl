plot_layout(raw::Raw) = plot_layout(raw.chans.location)

function plot_layout(layout::Layout)
    # Head measurement in centimeters
    circ = 55
    r = circ/2π * 10

    # Draw a circle with radius r
    x = cos.(0:0.02*π:2*π).*r
    y = sin.(0:0.02*π:2*π).*r

    axes_range = 120
    p = scatterplot(
        x, y, 
        border=:none, labels=false, grid=false, 
        height=31, width=61, 
        xlim=(-axes_range,axes_range), ylim=(-axes_range,axes_range)
    )

    layout = Spherical(layout)
    # Electrode distande from the origin (Cz)
    c = @. r*abs(layout.theta)/90
    
    # Compute x and y coordiantes for 2D space
    x2d = [layout.theta[i] < 0 ? -cos(deg2rad(layout.phi[i]))*c[i] : cos(deg2rad(layout.phi[i]))*c[i] for i in eachindex(layout.phi)];
    y2d = [layout.theta[i] < 0 ? -sin(deg2rad(layout.phi[i]))*c[i] : sin(deg2rad(layout.phi[i]))*c[i] for i in eachindex(layout.phi)];
    
    # Plot electrode locations
    scatterplot!(p, x2d, y2d, marker=:dot)
end