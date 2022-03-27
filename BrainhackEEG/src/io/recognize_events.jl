

function find_events(data::RawEEG)
    a_check = 0
    events_array = Vector[]
    for position in 1:length(data.lowTrigger)
        if data.lowTrigger[position] != a_check && data.lowTrigger[position] != 0
            push!(events_array, [position,data.lowTrigger[position]])
            a_check = data.lowTrigger[position]
        end    
    end
    return events_array
end
### find_events: Returns an Array with Vectors of time points paired with values of an event from EEG file called in read_bdf function.


function count_events(data::RawEEG)
    counter = 0
    a_check = 0
    for position in 1:length(data.lowTrigger)
        if data.lowTrigger[position] != a_check && data.lowTrigger[position] != 0
            counter += 1
        end  
        a_check = data.lowTrigger[position]
    end
    return counter
end
### count_events: Returns a number of events from EEG file called in read_bdf function.


function scatter_events(data::RawEEG)
    events = find_events(data)
    x_events = Float32[]
    y_events = Float32[]
    for eve in 1:length(events)
        push!(x_events,events[eve][1])
        push!(y_events,events[eve][2])
    end
    x_events_sec = x_events/2048

    sorted_unique_events = sort(unique(y_events))
    number_unique_events = Int[]
    for i in 1:length(sorted_unique_events)
        push!(number_unique_events, i)
    end
    
    y_events_new = Float32[]
    for elem in 1:length(y_events)
        no = indexin(y_events[elem], sorted_unique_events)
        push!(y_events_new, no[])
    end

    fig = Figure(resolution = (1920,1080))
    ax = fig[1,1] = Axis(fig, xlabel = "Time(s)", ylabel = "Event id")
    scatter!(ax, x_events_sec, y_events_new)
    ax.yticks = (number_unique_events,string.(Int.(sorted_unique_events)))
    display(fig)
end

# scatter_events: Returns a scatter plot of events on values occuring in time points.

function remove_channels(data::RawEEG, channels_to_remove::Vector)
    info_on_channels = ["chanLabels", "transducer", "physDim", "physMin","physMax","digMin", "digMax", "prefilt", "nSampRec", "reserved",  "scaleFactor", "sampRate"]
    all_channels = data.info["chanLabels"]
    no_channels_to_remove = Int[]
    for a in 1:length(channels_to_remove)
        push!(no_channels_to_remove, findfirst(==(channels_to_remove[a]), all_channels))
    end

    sorted_no_channels_to_removesort = sort(no_channels_to_remove, rev = true)
    for channel in 1:length(sorted_no_channels_to_removesort)
        for selected in 1:length(info_on_channels)
            deleteat!(data.info[info_on_channels[selected]], sorted_no_channels_to_removesort[channel])
        end
        data.data = data.data[:, 1:end .!= sorted_no_channels_to_removesort[channel]]
    end
end

#Function remove channels requires two parameters: data set in RawEEG format, and a vector of strings with channel names e.g. ["P3", "GSR1", "AF7"].