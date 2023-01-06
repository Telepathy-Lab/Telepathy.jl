# TODO: Allow finding events based on first-non-zero, same value for given period of time, increasing value

function find_events!(raw::Raw{BDF})

    if length(raw) > length(raw.status["lowTrigger"])
        parse_status!(raw)
    end
    
    events = []
    if length(unique(raw.status["lowTrigger"])) > 1
        push!(events, find_events(raw.status["lowTrigger"]))
    end

    if length(unique(raw.status["highTrigger"])) > 1
        push!(events, find_events(raw.status["lowTrigger"]))
    end

    if length(events) == 0
        println("No events found!")
    elseif length(events) == 1
        println("Found $(size(events[1],1)) occurences of $(length(unique(events[1][:,3]))) unique events.")
        raw.events = events[1]
        return nothing
    else
        output = sort!(vcat(events...), dims=1)
        println("Found events on both trigger groups, merged them into list of $(size(output,1)) occurences of $(length(unique(output[:,3]))) unique events.")
        raw.events = output
        return nothing
    end
end

# FIXME: Make parsing events more generic (now it is hardcoded to a specific use case)
function find_events(trigger::Vector)
    vec = diff(Int32.(trigger))
    trs = [filter(x -> x!=0,  vec) findall(x -> x!=0,  vec)]
    output = Array{Int64}(undef, (size(trs,1),3))
    row = 1
    for idx in eachindex(trs[1:end-1,1])
        if trs[idx,1] > 0
            if trs[idx,1] + trs[idx+1,1] != 0
                if trs[idx,1] + trs[idx+1,1] + trs[idx+2,1] != 0
                else
                    output[row,1] = trs[idx,2]
                    output[row,2] = trs[idx+2,2]
                    output[row,3] = trs[idx,1] + trs[idx+1,1]
                    row += 1
                end
            else
                output[row,1] = trs[idx,2]
                output[row,2] = trs[idx+1,2]
                output[row,3] = trs[idx,1]
                row += 1
            end
        end
    end
    return output[1:row-1,:]
end