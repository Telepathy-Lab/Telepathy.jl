function plot_filter(filter::Vector, srate; 
                    freq::Bool=true, phase::Bool=true, 
                    group::Bool=false, impulse::Bool=false, step::Bool=false)

    fig = Figure()
    axNum = 1

    # Transform the vector with filter values to coefficients expected by response functions
    coefs = PolynomialRatio(filter, [1.])

    # Estimate the number of points to make a smooth plot (> 5000)
    if srate < 10000
        multiplier = (10000 ÷ srate) + 1
    else
        multiplier = 1
    end

    xNum = multiplier*srate
    xPoints = (0:1/multiplier:srate)/2

    # Frequency response
    if freq
        freqAx = fig[axNum,1] = Axis(fig)
        axNum += 1

        
        fResp = freqresp(coefs, 0:π/xNum:π)
        fResp = 20*log10.(abs.(fResp))
        lines!(freqAx, xPoints, fResp, linewidth=0.75, color=:black)
    end

    # Phase response
    if phase
        phaseAx = fig[axNum,1] = Axis(fig)
        axNum += 1

        pResp = phaseresp(coefs, 0:π/xNum:π)
        lines!(phaseAx, xPoints, pResp, linewidth=0.75, color=:black)
    end

    # Group delay
    if group
        groupAx = fig[axNum,1] = Axis(fig)
        axNum += 1

        gDelay = grpdelay(coefs, 0:π/xNum:π)
        lines!(groupAx, xPoints, gDelay/2048, linewidth=0.75, color=:black)
        ylims!(groupAx, -0.2,0.2)
    end

    # Impulse response
    if impulse
        impAx = fig[axNum,1] = Axis(fig)
        axNum += 1

        samples = length(filter)
        stem!(impAx, impresp(coefs, samples), markersize=1, linewidth=0.5)
    end

    # Step response
    if step
        stepAx = fig[axNum,1] = Axis(fig)
        axNum += 1

        samples = length(filter)
        lines!(stepAx, stepresp(coefs, samples))
    end
    display(fig)
end