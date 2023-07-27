function decimate_epochs(paramss, newSpan)
    nPoints = length(paramss[1].timeSpan)*length(newSpan)
    @info "nPoints: $nPoints"
    newSpan = paramss[1].timeSpan

    if nPoints > paramss[1].buffSize
        @info "Trying to display $nPoints points. Increasing decimation rate to $(newSpan.step*2)"
        return newSpan.start:(newSpan.step*2):newSpan.stop
    elseif (nPoints < paramss[1].buffSize÷2) & (newSpan.step > 1)
        @info "Trying to display $nPoints points. Decreasing decimation rate to $(newSpan.step÷2)"
        return newSpan.start:(newSpan.step÷2):newSpan.stop
    end
    return newSpan
end

function get_bad_epoch_poly(params)
    if isempty(params[1].rec.bads)
        return Rect2f[]
    else
        idxs = findall(x -> x in params[1].rec.bads, params[1].epochSpan)
    end

    if isempty(idxs)
        return Rect2f[]
    else
        xDim = length(params[1].timeSpan)
        yDim = -100 * (params[1].nChannels + 1)
        return [Rect2f(Point2f(xDim*(idx-1), 100), Point2f(xDim, yDim)) for idx in idxs]
    end
end

update_buffers_epochs!(ax, ax2, params) = update_buffers_epochs!(ax, ax2, params, params[1].timeSpan, params[1].chanSelection, params[1].epochSpan)

function update_buffers_epochs!(ax, ax2, paramss, newTimeSpan, newChans, newEpochs)
    #@info "New time span: $newTimeSpan, new channels: $newChans, new epochs: $newEpochs"
    params = paramss[1]
    # Trigger only when there is a change in data selection
    if (params.timeSpan != newTimeSpan) || (params.chanSelection != newChans) || (params.epochSpan != newEpochs)
        oldSpan = length(params.timeSpan)*length(params.epochSpan)
        newSpan = length(newTimeSpan)*length(newEpochs)
        spanDiff = oldSpan - newSpan

        #@info "Old span: $oldSpan, new span: $newSpan, spanDiff: $spanDiff"

        # Deal with the channels that are no longer in scope
        chanDiff = setdiff(params.chanSelection, newChans)

        for idx in eachindex(paramss)
            for chan in chanDiff
                paramss[idx].buffVectors[chan][end-oldSpan+1:end] = Point2f.(
                    zeros(oldSpan), 
                    zeros(oldSpan))
            end

            paramss[1].timeSpan = newTimeSpan
            paramss[1].chanSelection = newChans
            paramss[1].epochSpan = newEpochs

            for chan in paramss[1].chanSelection

                # Deal with shortening of the signal in buffers 
                if spanDiff > 0
                    paramss[idx].buffVectors[chan][end-(newSpan+spanDiff)+1:end-newSpan] = Point2f.(
                        zeros(1:spanDiff),
                        zeros(1:spanDiff))
                end
            end
        end
    end

    # Redraw already visible datapoints
    for idx in eachindex(paramss)
        for chan in params.chanSelection
            if params.grouping != [0]
                placement = -100 * params.grouping[chan]
            else
                placement = -100*chan
            end
            # Deal with shortening of the signal in buffers 
            span = paramss[1].timeSpan
            for i in paramss[1].epochSpan
                j = i - paramss[1].epochSpan.start + 1
                shift = length(span)*(length(paramss[1].epochSpan)-j)                
                paramss[idx].buffVectors[chan][(end-length(span)+1:end).-shift] = Point2f.(
                    length(span)*(j-1)+1:length(span)*j, 
                    demean(paramss[idx].rec.data[span,chan,i]) .* paramss[1].scale .+ placement)
            end
        end
    end

    paramss[1].epochBorders[] = length(paramss[1].timeSpan):length(paramss[1].timeSpan):length(paramss[1].timeSpan)*(length(paramss[1].epochSpan)-1)

    paramss[1].buffBads[] = get_bad_epoch_poly(paramss)
    
    ax.xticks = get_ticks(paramss[1].timeSpan, paramss[1].srate, paramss[1].epochSpan)
    xlims!(ax, paramss[1].timeSpan.start, length(paramss[1].epochSpan)*length(paramss[1].timeSpan)+1)
    if paramss[1].grouping == [0]
        ylims!(ax, -100*paramss[1].chanSelection[end]-50, -100*paramss[1].chanSelection[1]+50)
    end

    pb = params.box
    pb[1][] = hstart = -(paramss[1].chanSelection[1]-1) / paramss[1].nChannels
    pb[2][] = height = length(paramss[1].chanSelection) / paramss[1].nChannels
    pb[3][] = wstart = paramss[1].epochSpan.start / paramss[1].nSegments
    pb[4][] = width = length(paramss[1].epochSpan) / paramss[1].nSegments

    xlims!(ax2, 0, 1)
    ylims!(ax2, -1, 0)
end

function get_ticks(dataSpan, srate::Float64, epochSpan)
    len = length(dataSpan)
    epochLen = length(epochSpan)
    ticks = collect(len/2:len:len*epochLen)

    # Generate string labels for calculated ticks
    tickLabels = string.(epochSpan)
    return ticks, tickLabels
end

function step_data_epoch(ax, ax2, paramss, step)
    params = paramss[1]
    span =  params.epochSpan
    newSpan = span .+ step
    
    if newSpan.start < 1
        newSpan = 1:length(span)
    end
    if newSpan.stop > params.nSegments
        newSpan = (params.nSegments-length(span)):params.nSegments
    end

    update_buffers_epochs!(ax, ax2, paramss, paramss[1].timeSpan, paramss[1].chanSelection, newSpan)
end

function change_span_epoch(ax, ax2, paramss, change)
    params = paramss[1]
    span = params.epochSpan
    newSpan = span.start:(span.start + round(Int, length(span)*change) - 1)

    if newSpan.start < 1
        newSpan = 1:newSpan.stop
    end
    if newSpan.stop > params.nSegments
        newSpan = newSpan.start:params.nSegments
    end

    buffSamples = length(newSpan) * length(params.timeSpan)
    if (buffSamples >= params.buffSize) | (buffSamples < params.buffSize/2)
        newTimeSpan = decimate_epochs(paramss, newSpan)
    else
        newTimeSpan = paramss[1].timeSpan
    end

    update_buffers_epochs!(ax, ax2, paramss, newTimeSpan, paramss[1].chanSelection, newSpan)
end

function change_chans_epoch(ax, ax2, paramss, position, amount)
    params = paramss[1]
    newChans = chans = params.chanSelection

    # Change the displayed channel indices according to position number
    if (position < 0) & (chans[1] > 1)
        newChans = vcat((chans[1]+position):(chans[1]-1), chans[1:end+position])
    elseif (position > 0) & (chans[end] < params.nChannels)
        newChans = vcat(chans[1+position:end], chans[end]+1:chans[end]+position)
    end
    
    # Change the amount of channels and make sure it is possible
    if (amount < 0) & (length(newChans) > 1)
        newChans = newChans[1:end-1]
    elseif (amount > 0) & (length(newChans) < params.nChannels)
        newChans = vcat(newChans, newChans[end]+1)
    end

    # Make sure channel indices are inbounds
    if any(x -> x < 1, newChans)
        newChans = 1:length(chans)
    end
    if any(x -> x > params.nChannels, newChans)
        newChans = (params.nChannels-length(chans)):params.nChannels
    end

    update_buffers_epochs!(ax, ax2, paramss, paramss[1].timeSpan, newChans, paramss[1].epochSpan)
end

function change_scale_epoch(ax, ax2, paramss, factor)
    paramss[1].scale *= factor
    update_buffers_epochs!(ax, ax2, paramss, paramss[1].timeSpan, paramss[1].chanSelection, paramss[1].epochSpan)
end

function change_grouping_epoch(ax, ax2, paramss)
    chans = paramss[1].rec.chans
    if paramss[1].grouping == [0]
        paramss[1].grouping = zeros(length(chans.type))
        
        chanTypes = unique(chans.type)
        for i in eachindex(chanTypes)
            paramss[1].grouping[findall(x -> x == chanTypes[i], chans.type)] .= i
        end

        newChans = 1:paramss[1].nChannels
        paramss[1].chanSave = paramss[1].chanSelection

        ax.yticks = (-100:-100:(-100*length(chanTypes)), string.(chanTypes))
        ylims!(ax, -100*length(chanTypes)-50, -50)
    else
        paramss[1].grouping = [0]

        newChans = paramss[1].chanSave
        ax.yticks = (-100:-100:-100*paramss[1].nChannels, chans.name)
    end
    update_buffers_epochs!(ax, ax2, paramss, paramss[1].timeSpan, newChans, paramss[1].epochSpan)
end

function draw!(ax, params, epochSpan; colors=[:black, :red, :green], linewidths=[0.5, 1, 1])
    poly!(ax, params[1].buffBads, color=(:red, 0.15))

    for idx in eachindex(params)
        for buff in params[idx].buffVectors
            lines!(ax, buff, color=colors[idx], linewidth=linewidths[idx])
        end
    end

    vlines!(ax, params[1].epochBorders, color=:black, linewidth=1, linestyle=:dash)
end

function Makie.plot(epochs::Epochs...; channels=1:20, epochSpan=1:10, step=0.25, hotkeys=rawHotkeys, buffSize=50_000)
    
    fig, plotAx, barAx, helpAx = create_browser_window()

    params = [BrowserParams(epoch) for epoch in epochs]
    params[1].chanSelection = _get_channels(epochs[1], channels)
    params[1].timeSpan = 1:1:size(epochs[1].data, 1)
    params[1].buffSize = buffSize
    params[1].epochSpan = epochSpan

    plotAx.yticks = (-100:-100:-100*params[1].nChannels, params[1].rec.chans.name)

    # Preallocate buffers with a reasonable length (e.g. keep total points below 5M)
    for param in params
        param.buffVectors = [
            Buffer(Point2f.(zeros(params[1].buffSize), zeros(params[1].buffSize))) for i in 1:params[1].nChannels
            ]
    end

    update_buffers_epochs!(plotAx, barAx, params)

    draw!(plotAx, params, params[1].epochSpan)

    on(events(fig).keyboardbutton) do event
        ispressed(fig, hotkeys["stepForw"]) && step_data_epoch(plotAx, barAx, params, 1)
        ispressed(fig, hotkeys["stepBack"]) && step_data_epoch(plotAx, barAx, params, -1)
        ispressed(fig, hotkeys["stepForwFull"]) && step_data_epoch(plotAx, barAx, params, length(params[1].epochSpan))
        ispressed(fig, hotkeys["stepBackFull"]) && step_data_epoch(plotAx, barAx, params, -length(params[1].epochSpan))

        ispressed(fig, hotkeys["moreSpan"]) && change_span_epoch(plotAx, barAx, params, 1.5) 
        ispressed(fig, hotkeys["lessSpan"]) && change_span_epoch(plotAx, barAx, params, 1/1.5)

        ispressed(fig, hotkeys["upChans"]) && change_chans_epoch(plotAx, barAx, params, -1, 0)
        ispressed(fig, hotkeys["downChans"]) && change_chans_epoch(plotAx, barAx, params, 1, 0)
        ispressed(fig, hotkeys["lessChans"]) && change_chans_epoch(plotAx, barAx, params, 0, -1)
        ispressed(fig, hotkeys["moreChans"]) && change_chans_epoch(plotAx, barAx, params, 0, 1)

        ispressed(fig, hotkeys["upScale"]) && change_scale_epoch(plotAx, barAx, params, 1.5)
        ispressed(fig, hotkeys["downScale"]) && change_scale_epoch(plotAx, barAx, params, 1/1.5)

        ispressed(fig, hotkeys["butterfly"]) && change_grouping_epoch(plotAx, barAx, params)

        ispressed(fig, hotkeys["help"]) && toggle_help(helpAx)
    end

    on(events(fig).scroll, priority=100) do (dx, dy)
        if is_mouseinside(plotAx)
            dy = -round(Int, dy)
            if dy < 0
                change_chans_epoch(plotAx, barAx, params, dy, 0)
            elseif dy > 0
                change_chans_epoch(plotAx, barAx, params, dy, 0)
            end
        end
        return Consume(true)
    end

    draw_map!(barAx, params)
    draw_help!(helpAx)

    hidespines!(barAx)
    hidedecorations!(barAx)

    display(fig)

    return fig, plotAx, barAx
end