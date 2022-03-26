function plot(data::RawEEG)
    fig = Figure(resolution = (1920,1080));
    ax = fig[1,1] = Axis(fig);

    step = Observable(1:2048)
    chanRange = Observable(1:20)

    on(events(fig).keyboardbutton) do event
        if event.action in (Keyboard.press, Keyboard.repeat)
            event.key == Keyboard.left   && step_back(ax, step, chanRange)
            event.key == Keyboard.right  && step_forw(ax, step, chanRange)
            event.key == Keyboard.up   && step_more(data, ax, step, chanRange)
            event.key == Keyboard.down  && step_less(data, ax, step, chanRange)
            event.key == Keyboard.page_down  && chans_less(data, ax, step, chanRange)
            event.key == Keyboard.page_up  && chans_more(data, ax, step, chanRange)
        end
        # Let the event reach other listeners
        return Consume(false)
    end

    ax.yticks = (-100:-100:-100*length(data.info["chanLabels"]), data.info["chanLabels"])
    xlims!(ax, step.val[1], step.val[end])
    ylims!(ax, -100*chanRange.val[end]-50, -100*chanRange.val[1]+50)

    draw(data, ax, step)
    visible(data, ax, chanRange)

    display(fig);
end

function draw(data::RawEEG, ax::Axis, step::Observable)
    for i=1:(length(data.info["chanLabels"])-1)
        lines!(ax, step, @lift(data.data[$step,i].-mean(data.data[$step,i]).-100i), color="black", visible=false)
    end
end

function visible(data::RawEEG, ax::Axis, chanRange::Observable)
    for j=1:(length(data.info["chanLabels"])-1)
        if j in chanRange.val
            ax.scene.plots[j].visible=true
        else
            ax.scene.plots[j].visible=false
        end
    end
end

function step_back(ax::Axis, step::Observable, chanRange::Observable)
    step[] = step.val.-100
    xlims!(ax, step.val[1], step.val[end])
    ylims!(ax, -100*chanRange.val[end]-50, -100*chanRange.val[1]+50)
end

function step_forw(ax::Axis, step::Observable, chanRange::Observable)
    step[] = step.val.+100
    xlims!(ax, step.val[1], step.val[end])
    ylims!(ax, -100*chanRange.val[end]-50, -100*chanRange.val[1]+50)
end

function step_more(data::RawEEG, ax::Axis, step::Observable, chanRange::Observable)
    chanRange[] = chanRange.val.start-1:chanRange.val.stop-1
    visible(data, ax, chanRange)
    xlims!(ax, step.val[1], step.val[end])
    ylims!(ax, -100*chanRange.val[end]-50, -100*chanRange.val[1]+50)
end

function step_less(data::RawEEG, ax::Axis, step::Observable, chanRange::Observable)
    chanRange[] = chanRange.val.start+1:chanRange.val.stop+1
    visible(data, ax, chanRange)
    xlims!(ax, step.val[1], step.val[end])
    ylims!(ax, -100*chanRange.val[end]-50, -100*chanRange.val[1]+50)
end

function chans_less(data::RawEEG, ax::Axis, step::Observable, chanRange::Observable)
    chanRange[] = chanRange.val.start:chanRange.val.stop-1
    visible(data, ax, chanRange)
    xlims!(ax, step.val[1], step.val[end])
    ylims!(ax, -100*chanRange.val[end]-50, -100*chanRange.val[1]+50)
end

function chans_more(data::RawEEG, ax::Axis, step::Observable, chanRange::Observable)
    chanRange[] = chanRange.val.start:chanRange.val.stop+1
    visible(data, ax, chanRange)
    xlims!(ax, step.val[1], step.val[end])
    ylims!(ax, -100*chanRange.val[end]-50, -100*chanRange.val[1]+50)
end