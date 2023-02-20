function plot_freq(axis, xNum, xPoints, coefs, color)
    fResp = freqresp(coefs, xNum)
    fResp = 20*log10.(abs.(fResp))
    lines!(axis, xPoints, fResp, linewidth=0.75, color=color)
    axis.title = "Frequency response"
end

function plot_phase(axis, xNum, xPoints, coefs, color)
    pResp = phaseresp(coefs, xNum)
    lines!(axis, xPoints, pResp, linewidth=0.75, color=color)
    axis.title = "Phase response"
end

function plot_group(axis, xNum, xPoints, coefs, color)
    gDelay = grpdelay(coefs, xNum)
    lines!(axis, xPoints, gDelay/2048, linewidth=0.75, color=color)
    ylims!(axis, -1,1)
    axis.title = "Group delay"
end

function plot_impulse(axis, xNum, xPoints, coefs, color)
    samples = length(coefs.b.coeffs)
    xPoints = (1:samples).-samples/2
    stem!(axis, xPoints, impresp(coefs, samples), markersize=1, linewidth=0.5, color=color, stemcolor=color)
    axis.title = "Impulse response"
end

function plot_step(axis, xNum, xPoints, coefs, color)
    samples = length(coefs.b.coeffs)
    xPoints = (1:samples).-samples/2
    lines!(axis, xPoints, stepresp(coefs, samples), color=color)
    axis.title = "Step response"
end


plot_filter(filterCoefs::Vector, srate; kwargs...) = plot_filters([filterCoefs], srate; kwargs...)

function plot_filters(filters::Vector, srate; 
                    freq::Bool=true, phase::Bool=true, 
                    group::Bool=false, impulse::Bool=false, step::Bool=false,
                    cutoff=0)
    
    fig = Figure()
    axNum = 1

    # Estimate the number of points to make a smooth plot (> 5000)
    if srate < 10000
        multiplier = (10000 ÷ srate) + 1
    else
        multiplier = 1
    end

    xNum = 0:(π/(multiplier*srate)):π
    xPoints = (0:1/multiplier:srate)/2
    
    # Show only the frequency range of interest
    if cutoff > 0
        nPoints = length(xNum)
        xNum = xNum[1:floor(Int, 3*nPoints*cutoff/srate)]
        xPoints = xPoints[1:floor(Int, 3*nPoints*cutoff/srate)]
        @info length(xNum), length(xPoints)
    end

    # Create axes for requested panels
    freq && (freqAx = fig[axNum,1] = Axis(fig); axNum += 1)
    phase && (phaseAx = fig[axNum,1] = Axis(fig); axNum += 1)
    group && (groupAx = fig[axNum,1] = Axis(fig); axNum += 1)
    impulse && (impAx = fig[axNum,1] = Axis(fig); axNum += 1)
    step && (stepAx = fig[axNum,1] = Axis(fig); axNum += 1)

    color=[:black, :red, :blue]

    for (idx, filterCoefs) in enumerate(filters)
        # Transform the vector with filter values to coefficients expected by response functions
        coefs = PolynomialRatio(filterCoefs, [1.])

        freq && plot_freq(freqAx, xNum, xPoints, coefs, color[idx])
        phase && plot_phase(phaseAx, xNum, xPoints, coefs, color[idx])
        group && plot_group(groupAx, xNum, xPoints, coefs, color[idx])
        impulse && plot_impulse(impAx, xNum, xPoints, coefs, color[idx])
        step && plot_step(stepAx, xNum, xPoints, coefs, color[idx])
    end

    display(fig)
end