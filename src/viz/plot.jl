function plot(data::RawEEG)
    println("does it?")
    fig = Figure(resolution = (1920,1080));
    ax = fig[1,1] = Axis(fig);

    step = Observable(1:2048)
    scale = Observable(1)
    chanRange = Observable(1:20)

    on(events(fig).keyboardbutton) do event
        if event.action in (Keyboard.press, Keyboard.repeat)
            event.key == Keyboard.left      && step_back(ax, step)
            event.key == Keyboard.right     && step_forw(ax, step)
            event.key == Keyboard.period    && step_more(ax, step)
            event.key == Keyboard.comma     && step_less(ax, step)
            event.key == Keyboard.up        && chans_up(ax, chanRange)
            event.key == Keyboard.down      && chans_down(ax, chanRange)
            event.key == Keyboard.page_down && chans_less(ax, chanRange)
            event.key == Keyboard.page_up   && chans_more(ax, chanRange)
            event.key == Keyboard.minus     && scale_down(ax, scale, step)
            event.key == Keyboard.equal     && scale_up(ax, scale, step)
        end
        # Let the event reach other listeners
        return Consume(false)
    end

    ax.yticks = (-100:-100:-100*length(data.info["chanLabels"]), data.info["chanLabels"])
    xlims!(ax, step.val[1], step.val[end])
    ylims!(ax, -100*chanRange.val[end]-50, -100*chanRange.val[1]+50)

    draw(data, ax, step, chanRange, scale)

    display(fig);
end

function draw(data::RawEEG, ax::Axis, step::Observable, chanRange::Observable, scale::Observable)
    for i=chanRange[]
        lines!(ax, step, @lift((data.data[$step,i].-mean(data.data[$step,i]).*$scale).-100i), color="black", visible=false)
    end
end

function step_back(ax::Axis, step::Observable)
    step[] = step.val.-100
    xlims!(ax, step.val[1], step.val[end])
end

function step_forw(ax::Axis, step::Observable)
    step[] = step.val.+100
    xlims!(ax, step.val[1], step.val[end])
end

function step_up(ax::Axis, chanRange::Observable)
    chanRange[] = chanRange.val.start-1:chanRange.val.stop-1
    ylims!(ax, -100*chanRange.val[end]-50, -100*chanRange.val[1]+50)
end

function step_down(ax::Axis, chanRange::Observable)
    chanRange[] = chanRange.val.start+1:chanRange.val.stop+1
    ylims!(ax, -100*chanRange.val[end]-50, -100*chanRange.val[1]+50)
end

function step_more(ax::Axis, step::Observable)
    step[] = step.val.start:step.val.stop+2048
    xlims!(ax, step.val[1], step.val[end])
end

function step_less(ax::Axis, step::Observable)
    step[] = step.val.start:step.val.stop-2048
    xlims!(ax, step.val[1], step.val[end])
end

function chans_less(ax::Axis, chanRange::Observable)
    chanRange[] = chanRange.val.start:chanRange.val.stop-1
    ylims!(ax, -100*chanRange.val[end]-50, -100*chanRange.val[1]+50)
end

function chans_more(ax::Axis, chanRange::Observable)
    chanRange[] = chanRange.val.start:chanRange.val.stop+1
    ylims!(ax, -100*chanRange.val[end]-50, -100*chanRange.val[1]+50)
end

function scale_up(ax::Axis, scale::Observable, step::Observable)
    scale[] = scale.val*1.2
    xlims!(ax, step.val[1], step.val[end])
end

function scale_down(ax::Axis, scale::Observable, step::Observable)
    scale[] = scale.val/1.2
    xlims!(ax, step.val[1], step.val[end])
end