rawHotkeys = Dict(
    "stepBack" => Exclusively(Keyboard.left),
    "stepForw" => Exclusively(Keyboard.right),
    "stepBackFull" => Exclusively(((Keyboard.left_shift | Keyboard.right_shift) & Keyboard.left)),
    "stepForwFull" => Exclusively(((Keyboard.left_shift | Keyboard.right_shift) & Keyboard.right)),
    "lessSpan" => Exclusively(Keyboard.comma),
    "moreSpan" => Exclusively(Keyboard.period),
    "upChans" => Exclusively(Keyboard.up),
    "downChans" => Exclusively(Keyboard.down),
    "lessChans" => Exclusively(Keyboard.page_down),
    "moreChans" => Exclusively(Keyboard.page_up),
    "upScale" => Exclusively(Keyboard.equal),
    "downScale" => Exclusively(Keyboard.minus),
    "butterfly" => Exclusively(Keyboard.b),
)

function demean(vec::AbstractVector)
    return vec .- mean(vec)
end

function decimate(newSpan, buffSize)
    nPoints = length(newSpan)
    
    if nPoints > buffSize
        @debug "Trying to display $nPoints points. Increasing decimation rate to $(newSpan.step*2)"
        return newSpan.start:(newSpan.step*2):newSpan.stop
    elseif (nPoints < buffSize÷2) & (newSpan.step > 1)
        @debug "Trying to display $nPoints points. Decreasing decimation rate to $(newSpan.step÷2)"
        return newSpan.start:(newSpan.step÷2):newSpan.stop
    end
    return newSpan
end

update_buffers!(ax, ax2, params) = update_buffers!(ax, ax2, params, params["timeSpan"], params["chanSelection"])

function update_buffers!(ax, ax2, params, newSpan, newChans)
    
    # Trigger only when there is a change in data selection
    if (params["timeSpan"] != newSpan) | (params["chanSelection"] != newChans)
        spanDiff = length(params["timeSpan"]) - length(newSpan)
        
        # Deal with the channels that are no longer in scope
        chanDiff = setdiff(params["chanSelection"], newChans)

        for buffVector in params["buffVectors"]
            for chan in chanDiff
                buffVector[chan][end-length(params["timeSpan"])+1:end] = Point2f.(
                    zeros(length(params["timeSpan"])), 
                    zeros(length(params["timeSpan"])))
            end

            params["timeSpan"] = newSpan
            params["chanSelection"] = newChans

            for chan in params["chanSelection"]

                # Deal with shortening of the signal in buffers 
                span = params["timeSpan"]
                if spanDiff > 0
                    buffVector[chan][end-(length(span)+spanDiff)+1:end-length(span)] = Point2f.(
                        zeros(1:spanDiff),
                        zeros(1:spanDiff))
                end
            end
        end
    end

    # Redraw already visible datapoints
    for idx in eachindex(params["buffVectors"])
        for chan in params["chanSelection"]
            if params["grouping"] != 0
                placement = -100 *params["grouping"][chan]
            else
                placement = -100*chan
            end
            # Deal with shortening of the signal in buffers 
            span = params["timeSpan"]
            params["buffVectors"][idx][chan][end-length(span)+1:end] = Point2f.(
                span, 
                demean(params["data"][idx].data[span,chan]) .* params["scale"] .+ placement)
        end
    end
    
    ax.xticks = get_ticks(params["timeSpan"], params["srate"])
    xlims!(ax, params["timeSpan"].start, params["timeSpan"].stop+1)
    if params["grouping"] == 0
        ylims!(ax, -100*params["chanSelection"][end]-50, -100*params["chanSelection"][1]+50)
    end

    pb = params["box"]
    pb[1][] = hstart = -(params["chanSelection"][1]-1) / params["allChan"]
    pb[2][] = height = length(params["chanSelection"]) / params["allChan"]
    span = params["timeSpan"]
    pb[3][] = wstart = span.start / params["sigLength"]
    pb[4][] = width = (span.stop - span.start + 1) / params["sigLength"]

    xlims!(ax2, 0, 1)
    ylims!(ax2, -1, 0)
end

function get_ticks(dataSpan, srate::Integer)
    # Include the tick at the end to make xticks symmetric 
    # if N samples is a multiple of sample rate.
    newValues = dataSpan.start:(dataSpan.stop+1)
    len = dataSpan.stop - dataSpan.start + 1
    # Deal with timespans smaller then 10 times sample rate

    # Find the optimal multiple of smaple rate to fit around 10 ticks
    prec = -floor(Int, log10(len/(srate*10)))
    tmpSrate = round(len/(srate*10), digits=prec)*srate
    firstTick = dataSpan.start÷tmpSrate
    firstTick += mod(dataSpan.start-1, tmpSrate) == 0 ? 0 : 1
    firstTick *= tmpSrate

    ticks = collect(firstTick:tmpSrate:newValues.stop).+1

    # Generate string labels for calculated ticks
    tickLabels = string.(round.((ticks .- 1) ./ srate, digits=prec))
    return ticks, tickLabels
end

function step_data(ax, ax2, params, step)
    span = params["timeSpan"]
    len = span.stop - span.start + 1
    newSpan = span .+ round(Int, len*step)
    
    if newSpan.start < 1
        newSpan = 1:span.step:len
    end
    if newSpan.stop > params["sigLength"]
        newSpan = (params["sigLength"]-len):span.step:params["sigLength"]
    end

    update_buffers!(ax, ax2, params, newSpan, params["chanSelection"])
end

function change_span(ax, ax2, params, change)
    span = params["timeSpan"]
    newSpan = span.start:span.step:(span.start + round(Int, (span.stop-span.start+1)*change))

    if newSpan.start < 1
        newSpan = 1:span.step:newSpan.stop
    end
    if newSpan.stop > params["sigLength"]
        newSpan = newSpan.start:span.step:params["sigLength"]
    end

    if (length(newSpan) >= params["buffSize"]) | (length(newSpan) < params["buffSize"]/2)
        newSpan = decimate(newSpan, params["buffSize"])
    end

    update_buffers!(ax, ax2, params, newSpan, params["chanSelection"])
end

function change_chans(ax, ax2, params, position, amount)
    newChans = chans = params["chanSelection"]

    # Change the displayed channel indices according to position number
    if (position < 0) & (chans[1] > 1)
        newChans = vcat((chans[1]+position):(chans[1]-1), chans[1:end+position])
    elseif (position > 0) & (chans[end] < params["allChan"])
        newChans = vcat(chans[1+position:end], chans[end]+1:chans[end]+position)
    end
    
    # Change the amount of channels and make sure it is possible
    if (amount < 0) & (length(newChans) > 1)
        newChans = newChans[1:end-1]
    elseif (amount > 0) & (length(newChans) < params["allChan"])
        newChans = vcat(newChans, newChans[end]+1)
    end

    # Make sure channel indices are inbounds
    if any(x -> x < 1, newChans)
        newChans = 1:length(chans)
    end
    if any(x -> x > params["allChan"], newChans)
        newChans = (params["allChan"]-length(chans)):params["allChan"]
    end

    update_buffers!(ax, ax2, params, params["timeSpan"], newChans)
end

function change_scale(ax, ax2, params, factor)
    params["scale"] *= factor
    update_buffers!(ax, ax2, params, params["timeSpan"], params["chanSelection"])
end

function change_grouping(ax, ax2, params)
    chans = params["data"][1].chans
    if params["grouping"] == 0
        params["grouping"] = zeros(length(chans.type))
        
        chanTypes = unique(chans.type)
        for i in eachindex(chanTypes)
            params["grouping"][findall(x -> x == chanTypes[i], chans.type)] .= i
        end

        newChans = 1:params["allChan"]
        params["chanSave"] = params["chanSelection"]

        ax.yticks = (-100:-100:(-100*length(chanTypes)), string.(chanTypes))
        ylims!(ax, -100*length(chanTypes)-50, -50)
    else
        params["grouping"] = 0

        newChans = params["chanSave"]
        ax.yticks = (-100:-100:-100*params["allChan"], chans.name)
    end
    update_buffers!(ax, ax2, params, params["timeSpan"], newChans)
end

function draw!(ax, params; colors=[:black], linewidths=[0.5])
    for idx in eachindex(params["buffVectors"])
        for buff in params["buffVectors"][idx]
            lines!(ax, buff, color=colors[idx], linewidth=linewidths[idx])
        end
    end
end

function draw_map!(ax2, params)
    poly!(ax2, params["mapBuffer"], color=:white, strokewidth=1, strokecolor=:black)
end

function Makie.plot(raw::Raw; channels=1:20, timeSpan=10., step=0.25, hotkeys=rawHotkeys, buffSize=50_000)
    
    fig = Figure(resolution=(1000, 600), figure_padding=(10,30,10,5))
    ax = fig[1:9,1] = Axis(fig)
    ax2 = fig[10,1] = Axis(fig, backgroundcolor = (:black, 0.25), height=50)

    params = Dict(
        "data" => [raw],
        "buffSize" => buffSize,
        "srate" => raw.chans.srate[1],
        "sigLength" => size(raw.data, 1),
        "allChan" => size(raw.data, 2),
        "chanSelection" => get_channels(raw, channels),
        "chanSave" => [0],
        "timeSpan" => 1:1:round(Int, raw.chans.srate[1]*timeSpan),
        "scale" => 1.,
        "grouping" => 0,
    )

    ax.xticks = get_ticks(params["timeSpan"], params["srate"])
    ax.yticks = (-100:-100:-100*params["allChan"], params["data"][1].chans.name)

    # Preallocate buffers with a reasonable length (e.g. keep total points below 5M)
    params["buffVectors"] = [
        [Buffer(Point2f.(zeros(params["buffSize"]), zeros(params["buffSize"]))) for i in 1:params["allChan"]]
        ]
    
    pb = params["box"] = [Observable(0.), Observable(0.), Observable(0.), Observable(0.)]
    params["mapBuffer"] = @lift(Point2f[
        ($(pb[3]), $(pb[1])),
        ($(pb[3]), $(pb[1]) - $(pb[2])),
        ($(pb[3]) + $(pb[4]), $(pb[1]) - $(pb[2])),
        ($(pb[3]) + $(pb[4]), $(pb[1]))
        ])

    update_buffers!(ax, ax2, params)

    draw!(ax, params)

    xlims!(ax, params["timeSpan"].start, params["timeSpan"].stop+1)
    ylims!(ax, -100*length(params["chanSelection"])-50, -100*params["chanSelection"][1]+50)

    on(events(fig).keyboardbutton) do event
        ispressed(fig, hotkeys["stepForw"]) && step_data(ax, ax2, params, step)
        ispressed(fig, hotkeys["stepBack"]) && step_data(ax, ax2, params, -step)
        ispressed(fig, hotkeys["stepForwFull"]) && step_data(ax, ax2, params, 1)
        ispressed(fig, hotkeys["stepBackFull"]) && step_data(ax, ax2, params, -1)

        ispressed(fig, rawHotkeys["moreSpan"]) && change_span(ax, ax2, params, 1.5) 
        ispressed(fig, rawHotkeys["lessSpan"]) && change_span(ax, ax2, params, 1/1.5)

        ispressed(fig, rawHotkeys["upChans"]) && change_chans(ax, ax2, params, -1, 0)
        ispressed(fig, rawHotkeys["downChans"]) && change_chans(ax, ax2, params, 1, 0)
        ispressed(fig, rawHotkeys["lessChans"]) && change_chans(ax, ax2, params, 0, -1)
        ispressed(fig, rawHotkeys["moreChans"]) && change_chans(ax, ax2, params, 0, 1)

        ispressed(fig, rawHotkeys["upScale"]) && change_scale(ax, ax2, params, 1.5)
        ispressed(fig, rawHotkeys["downScale"]) && change_scale(ax, ax2, params, 1/1.5)

        ispressed(fig, rawHotkeys["butterfly"]) && change_grouping(ax, ax2, params)
    end

    draw_map!(ax2, params)

    xlims!(ax2, 0, 1)
    ylims!(ax2, -1, 0)
    hidespines!(ax2)
    hidedecorations!(ax2)

    ax.xticklabelsize = 14
    ax.yticklabelsize = 12

    display(fig)

    return fig, ax, ax2
end

function Makie.plot(rawOne::Raw, rawTwo::Raw; channels=1:20, timeSpan=10., step=0.25, hotkeys=rawHotkeys, buffSize=50_000)

    if size(rawOne.data) != size(rawTwo.data)
        error("Overlay plotting for datasets of different size is not implemented.")
    end
    
    fig = Figure(resolution=(1000, 600), figure_padding=(10,30,10,5))
    ax = fig[1:9,1] = Axis(fig)
    ax2 = fig[10,1] = Axis(fig, backgroundcolor = (:black, 0.25), height=50)

    params = Dict(
        "data" => [rawOne, rawTwo],
        "buffSize" => buffSize,
        "srate" => rawOne.chans.srate[1],
        "sigLength" => size(rawOne.data, 1),
        "allChan" => size(rawOne.data, 2),
        "chanSelection" => get_channels(rawOne, channels),
        "chanSave" => [0],
        "timeSpan" => 1:1:round(Int, rawOne.chans.srate[1]*timeSpan),
        "scale" => 1.,
        "grouping" => 0,
    )

    ax.xticks = get_ticks(params["timeSpan"], params["srate"])
    ax.yticks = (-100:-100:-100*params["allChan"], params["data"][1].chans.name)

    # Preallocate buffers with a reasonable length (e.g. keep total points below 5M)
    params["buffVectors"] = [
        [Buffer(Point2f.(zeros(params["buffSize"]), zeros(params["buffSize"]))) for i in 1:params["allChan"]],
        [Buffer(Point2f.(zeros(params["buffSize"]), zeros(params["buffSize"]))) for i in 1:params["allChan"]]
    ]
    
    pb = params["box"] = [Observable(0.), Observable(0.), Observable(0.), Observable(0.)]
    params["mapBuffer"] = @lift(Point2f[
        ($(pb[3]), $(pb[1])),
        ($(pb[3]), $(pb[1]) - $(pb[2])),
        ($(pb[3]) + $(pb[4]), $(pb[1]) - $(pb[2])),
        ($(pb[3]) + $(pb[4]), $(pb[1]))
        ])

    update_buffers!(ax, ax2, params)

    draw!(ax, params, colors=[:grey, :tomato], linewidths=[0.5,1.0])

    xlims!(ax, params["timeSpan"].start, params["timeSpan"].stop+1)
    ylims!(ax, -100*length(params["chanSelection"])-50, -100*params["chanSelection"][1]+50)

    on(events(fig).keyboardbutton) do event
        ispressed(fig, hotkeys["stepForw"]) && step_data(ax, ax2, params, step)
        ispressed(fig, hotkeys["stepBack"]) && step_data(ax, ax2, params, -step)
        ispressed(fig, hotkeys["stepForwFull"]) && step_data(ax, ax2, params, 1)
        ispressed(fig, hotkeys["stepBackFull"]) && step_data(ax, ax2, params, -1)

        ispressed(fig, rawHotkeys["moreSpan"]) && change_span(ax, ax2, params, 1.5) 
        ispressed(fig, rawHotkeys["lessSpan"]) && change_span(ax, ax2, params, 1/1.5)

        ispressed(fig, rawHotkeys["upChans"]) && change_chans(ax, ax2, params, -1, 0)
        ispressed(fig, rawHotkeys["downChans"]) && change_chans(ax, ax2, params, 1, 0)
        ispressed(fig, rawHotkeys["lessChans"]) && change_chans(ax, ax2, params, 0, -1)
        ispressed(fig, rawHotkeys["moreChans"]) && change_chans(ax, ax2, params, 0, 1)

        ispressed(fig, rawHotkeys["upScale"]) && change_scale(ax, ax2, params, 1.5)
        ispressed(fig, rawHotkeys["downScale"]) && change_scale(ax, ax2, params, 1/1.5)

        ispressed(fig, rawHotkeys["butterfly"]) && change_grouping(ax, ax2, params)
    end

    draw_map!(ax2, params)

    xlims!(ax2, 0, 1)
    ylims!(ax2, -1, 0)
    hidespines!(ax2)
    hidedecorations!(ax2)

    ax.xticklabelsize = 14
    ax.yticklabelsize = 12

    display(fig)
end