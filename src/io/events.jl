function find_events!(data::Raw{BDF})

    if length(data) > length(data.status["lowTrigger"])
        parse_status!(data)
    end

    data.events = find_events(data.status)
end

function find_events(status::Dict)
    unique(status["lowTrigger"])
end