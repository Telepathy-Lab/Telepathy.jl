mutable struct BrowserParams
    rec::Recording
    srate::Float64
    nSamples::Int
    nChannels::Int
    nSegments::Int
    chanAll::Vector{Int}
    chanSelection::Vector{Int}
    chanSave::Vector{Int}
    timeSpan::StepRange{Int}
    scale::Float64
    grouping::Vector{Int}
    buffSize::Int
    buffVectors::Vector{<:Buffer}
    box::Vector{<:Observable}
    mapBuffer::Observable{<:Vector{<:Point2f}}
end

function BrowserParams(rec::Recording)
    srate = get_srate(rec)
    nSamples = size(rec.data, 1)
    nChannels = size(rec.data, 2)
    nSegments = size(rec.data, 3)
    chanAll = get_channels(rec, :)
    chanSelection = get_channels(rec, :)
    chanSave = [0]
    timeSpan = 1:1:round(Int, srate*10)
    scale = 1.
    grouping = [0]
    buffSize = 50_000
    buffVectors = [Buffer(Point2f.(zeros(1), zeros(1)))]
    box = [Observable(0.), Observable(0.), Observable(0.), Observable(0.)]
    mapBuffer = @lift(Point2f[
        ($(box[3]), $(box[1])),
        ($(box[3]), $(box[1]) - $(box[2])),
        ($(box[3]) + $(box[4]), $(box[1]) - $(box[2])),
        ($(box[3]) + $(box[4]), $(box[1]))
        ])
    return BrowserParams(rec, srate, nSamples, nChannels, nSegments, chanAll, chanSelection, 
    chanSave, timeSpan, scale, grouping, buffSize, buffVectors, box, mapBuffer)
end


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

function create_browser_window(; resolution=(800, 600))
    fig = Figure(resolution=resolution, figure_padding=(10,30,10,5))
    plotAx = fig[1:9,1] = Axis(fig)
    barAx = fig[10,1] = Axis(fig, backgroundcolor = (:black, 0.25), height=50)

    plotAx.xticklabelsize = 14
    plotAx.yticklabelsize = 12
    return fig, plotAx, barAx
end

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

update_buffers!(ax, ax2, params) = update_buffers!(ax, ax2, params, params[1].timeSpan, params[1].chanSelection)

function update_buffers!(ax, ax2, paramss, newSpan, newChans)
    params = paramss[1]
    # Trigger only when there is a change in data selection
    if (params.timeSpan != newSpan) | (params.chanSelection != newChans)
        spanDiff = length(params.timeSpan) - length(newSpan)
        
        # Deal with the channels that are no longer in scope
        chanDiff = setdiff(params.chanSelection, newChans)

        for idx in eachindex(paramss)
            for chan in chanDiff
                paramss[idx].buffVectors[chan][end-length(params.timeSpan)+1:end] = Point2f.(
                    zeros(length(params.timeSpan)), 
                    zeros(length(params.timeSpan)))
            end

            params.timeSpan = newSpan
            params.chanSelection = newChans

            for chan in params.chanSelection

                # Deal with shortening of the signal in buffers 
                span = params.timeSpan
                if spanDiff > 0
                    paramss[idx].buffVectors[chan][end-(length(span)+spanDiff)+1:end-length(span)] = Point2f.(
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
            span = params.timeSpan
            paramss[idx].buffVectors[chan][end-length(span)+1:end] = Point2f.(
                span, 
                demean(paramss[idx].rec.data[span,chan]) .* params.scale .+ placement)
        end
    end

    
    ax.xticks = get_ticks(params.timeSpan, params.srate)
    xlims!(ax, params.timeSpan.start, params.timeSpan.stop+1)
    if params.grouping == [0]
        ylims!(ax, -100*params.chanSelection[end]-50, -100*params.chanSelection[1]+50)
    end

    pb = params.box
    pb[1][] = hstart = -(params.chanSelection[1]-1) / params.nChannels
    pb[2][] = height = length(params.chanSelection) / params.nChannels
    span = params.timeSpan
    pb[3][] = wstart = span.start / params.nSamples
    pb[4][] = width = (span.stop - span.start + 1) / params.nSamples

    xlims!(ax2, 0, 1)
    ylims!(ax2, -1, 0)
end

function get_ticks(dataSpan, srate::Float64)
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

function step_data(ax, ax2, paramss, step)
    params = paramss[1]
    span = params.timeSpan
    len = span.stop - span.start + 1
    newSpan = span .+ round(Int, len*step)
    
    if newSpan.start < 1
        newSpan = 1:span.step:len
    end
    if newSpan.stop > params.nSamples
        newSpan = (params.nSamples-len):span.step:params.nSamples
    end

    update_buffers!(ax, ax2, paramss, newSpan, params.chanSelection)
end

function change_span(ax, ax2, paramss, change)
    params = paramss[1]
    span = params.timeSpan
    newSpan = span.start:span.step:(span.start + round(Int, (span.stop-span.start+1)*change))

    if newSpan.start < 1
        newSpan = 1:span.step:newSpan.stop
    end
    if newSpan.stop > params.nSamples
        newSpan = newSpan.start:span.step:params.nSamples
    end

    if (length(newSpan) >= params.buffSize) | (length(newSpan) < params.buffSize/2)
        newSpan = decimate(newSpan, params.buffSize)
    end

    update_buffers!(ax, ax2, paramss, newSpan, params.chanSelection)
end

function change_chans(ax, ax2, paramss, position, amount)
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

    update_buffers!(ax, ax2, paramss, params.timeSpan, newChans)
end

function change_scale(ax, ax2, paramss, factor)
    params = paramss[1]
    params.scale *= factor
    update_buffers!(ax, ax2, paramss, params.timeSpan, params.chanSelection)
end

function change_grouping(ax, ax2, paramss)
    params = paramss[1]
    chans = params.rec.chans
    if params.grouping == [0]
        params.grouping = zeros(length(chans.type))
        
        chanTypes = unique(chans.type)
        for i in eachindex(chanTypes)
            params.grouping[findall(x -> x == chanTypes[i], chans.type)] .= i
        end

        newChans = 1:params.nChannels
        params.chanSave = params.chanSelection

        ax.yticks = (-100:-100:(-100*length(chanTypes)), string.(chanTypes))
        ylims!(ax, -100*length(chanTypes)-50, -50)
    else
        params.grouping = [0]

        newChans = params.chanSave
        ax.yticks = (-100:-100:-100*params.nChannels, chans.name)
    end
    update_buffers!(ax, ax2, paramss, params.timeSpan, newChans)
end

function draw!(ax, params; colors=[:black, :red, :green], linewidths=[0.5, 1, 1])
    for idx in eachindex(params)
        for buff in params[idx].buffVectors
            lines!(ax, buff, color=colors[idx], linewidth=linewidths[idx])
        end
    end
end

function draw_map!(ax2, params)
    poly!(ax2, params[1].mapBuffer, color=:white, strokewidth=1, strokecolor=:black)
end

function Makie.plot(raws::Raw...; channels=1:20, timeSpan=10., step=0.25, hotkeys=rawHotkeys, buffSize=50_000)
    
    fig, plotAx, barAx = create_browser_window()

    params = [BrowserParams(raw) for raw in raws]
    params[1].chanSelection = get_channels(raws[1], channels)
    params[1].timeSpan = 1:1:round(Int, raws[1].chans.srate[1]*timeSpan)
    params[1].buffSize = buffSize

    plotAx.yticks = (-100:-100:-100*params[1].nChannels, params[1].rec.chans.name)

    # Preallocate buffers with a reasonable length (e.g. keep total points below 5M)
    for param in params
        param.buffVectors = [
            Buffer(Point2f.(zeros(params[1].buffSize), zeros(params[1].buffSize))) for i in 1:params[1].nChannels
            ]
    end

    update_buffers!(plotAx, barAx, params)

    draw!(plotAx, params)

    xlims!(plotAx, params[1].timeSpan.start, params[1].timeSpan.stop+1)
    ylims!(plotAx, -100*length(params[1].chanSelection)-50, -100*params[1].chanSelection[1]+50)

    on(events(fig).keyboardbutton) do event
        ispressed(fig, hotkeys["stepForw"]) && step_data(plotAx, barAx, params, step)
        ispressed(fig, hotkeys["stepBack"]) && step_data(plotAx, barAx, params, -step)
        ispressed(fig, hotkeys["stepForwFull"]) && step_data(plotAx, barAx, params, 1)
        ispressed(fig, hotkeys["stepBackFull"]) && step_data(plotAx, barAx, params, -1)

        ispressed(fig, hotkeys["moreSpan"]) && change_span(plotAx, barAx, params, 1.5) 
        ispressed(fig, hotkeys["lessSpan"]) && change_span(plotAx, barAx, params, 1/1.5)

        ispressed(fig, hotkeys["upChans"]) && change_chans(plotAx, barAx, params, -1, 0)
        ispressed(fig, hotkeys["downChans"]) && change_chans(plotAx, barAx, params, 1, 0)
        ispressed(fig, hotkeys["lessChans"]) && change_chans(plotAx, barAx, params, 0, -1)
        ispressed(fig, hotkeys["moreChans"]) && change_chans(plotAx, barAx, params, 0, 1)

        ispressed(fig, hotkeys["upScale"]) && change_scale(plotAx, barAx, params, 1.5)
        ispressed(fig, hotkeys["downScale"]) && change_scale(plotAx, barAx, params, 1/1.5)

        ispressed(fig, hotkeys["butterfly"]) && change_grouping(plotAx, barAx, params)
    end

    draw_map!(barAx, params)

    xlims!(barAx, 0, 1)
    ylims!(barAx, -1, 0)
    hidespines!(barAx)
    hidedecorations!(barAx)

    display(fig)

    return fig, plotAx, barAx
end