function event_indices(events::Vector)
    new_events = copy(events)
    ordered = sort(unique(new_events))
    for (idx, val) in enumerate(ordered)
        replace!(new_events, val => idx)
    end
    return ordered, new_events
end

function plot_events(raw::Raw)
    ordered, new_events = event_indices(raw.events[:,3])

    fig = Figure(resolution = (800, 600))
    ax = fig[1,1] = Axis(fig, xlabel = "Time (s)", ylabel = "Event id")

    for (idx, event) in enumerate(ordered)
        @info event
        event_indices = findall(new_events .== idx)
        event_times = raw.events[event_indices, 1] ./ get_srate(raw)
        scatter!(ax, event_times, idx .* ones(length(event_times)), markersize=6)
    end
    ax.yticks = 1:length(ordered), string.(Int.(ordered))

    display(fig)

    return fig
end