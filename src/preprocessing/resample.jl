function resample!(raw::Raw, newSrate::Int; type=:FFT, nThreads=options.nThreads)

    # Pick only EEG data for resampling
    # Other channels are assumed to be digital and will be decimated
    chansEEG = get_channels(raw, :EEG)
    oldSrate = raw.chans.srate[1]
    sRatio = newSrate / oldSrate
    oldLength = size(raw.data, 1)
    newLength = Int(oldLength*newSrate/oldSrate)

    # Preallocate an array for resampled data
    resampledData = zeros(Float32, newLength, size(raw.data,2))

    if type == :FFT
        resample!(raw, resampledData, chansEEG, sRatio, oldLength, newLength, nThreads)
    elseif type == :POLY
        resample!(raw, resampledData, chansEEG, sRatio, oldLength, nThreads)
    end
    return resampledData
end

function resample!(raw::Raw, resampledData, chansEEG, sRatio, oldLength, newLength, nThreads)
    fftLength = sRatio < 1 ? oldLength+1 : newLength +1

    inputBuffer = [zeros(Float32, oldLength*2) for i in 1:nThreads]
    fftBuffer = [zeros(ComplexF32, fftLength) for i in 1:nThreads]
    outputBuffer = [zeros(Float32, newLength*2) for i in 1:nThreads]
    
    @views inputBuffer[1][1:oldLength] .= raw.data[:, chansEEG[1]]
    @views inputBuffer[1][end:-1:oldLength+1] .= raw.data[:, chansEEG[1]]
    
    rfftPlan = plan_rfft(inputBuffer[1])
    irfftPlan = plan_irfft(fftBuffer[1][1:newLength+1], newLength*2)
        
    @views dataSubarray = raw.data[:,chansEEG]
    Threads.@threads for (thrID, batch) in setup_workers(axes(dataSubarray, 2), nThreads)
        for chan in batch
        #for chan in axes(dataSubarray, 2)
            @debug thrID, chan
            resample_channel!(inputBuffer[thrID], fftBuffer[thrID], outputBuffer[thrID], 
            raw, chan, resampledData, rfftPlan, irfftPlan, oldLength, newLength, sRatio)
        end
    end
end

function resample_channel!(inputBuffer, fftBuffer, outputBuffer, raw, chan, resampledData, 
    rfftPlan, irfftPlan, oldLength, newLength, sRatio)

    @views begin
        inputBuffer[1:oldLength] .= raw.data[:, chan]
        inputBuffer[end:-1:oldLength+1] .= raw.data[:, chan]

        mul!(fftBuffer[1:oldLength+1], rfftPlan, inputBuffer)
        mul!(outputBuffer, irfftPlan, fftBuffer[1:newLength+1])

        resampledData[:, chan] .= outputBuffer[1:newLength] .* sRatio
    end
end

function resample!(raw::Raw, resampledData, chansEEG, sRatio, oldLength, nThreads)
    h = resample_filter(sRatio)
    polyFIR = [FIRFilter(h, sRatio) for thr in 1:nThreads]
    tDelta = timedelay(polyFIR[1])

    τ = timedelay(polyFIR[1])
    setphase!.(polyFIR, τ)

    # We are padding the data with 1s of mirrored values on both ends
    oldRate = raw.chans.srate[1]
    newRate = Int(oldRate*sRatio)

    mirrorBuffer = oldLength+2*oldRate
    outLen       = ceil(Int, mirrorBuffer*sRatio)
    reqInlen     = inputlength(polyFIR[1], outLen)
    reqZerosLen  = reqInlen - mirrorBuffer
    
    inputBuffer  = [zeros(Float32, mirrorBuffer+reqZerosLen) for thr in 1:nThreads]
    outputBuffer = [zeros(Float32, Int(mirrorBuffer*sRatio)) for thr in 1:nThreads]
    
    @views dataSubarray = raw.data[:,chansEEG]
    Threads.@threads for (thrID, batch) in setup_workers(axes(dataSubarray, 2), nThreads)
        for chan in batch
            @debug thrID, chan
            resample_channel!(inputBuffer, outputBuffer, raw, resampledData, oldRate, oldLength, 
            newRate, reqZerosLen, polyFIR, τ, chan, thrID)
        end
    end
end

function resample_channel!(inputBuffer, outputBuffer, raw, resampledData, oldRate, oldLength, 
    newRate, reqZerosLen, polyFIR, τ, chan, thrID)

    inputBuffer[thrID][1:oldRate] .= view(raw.data, oldRate:-1:1, chan)
    inputBuffer[thrID][oldRate+1:oldRate+oldLength] .= view(raw.data, :, chan)
    inputBuffer[thrID][oldRate+oldLength+1:(end-reqZerosLen)] .= view(raw.data, oldLength:-1:(oldLength-oldRate+1), chan)
    filt!(outputBuffer[thrID], polyFIR[thrID], inputBuffer[thrID])
    setphase!(polyFIR[thrID], τ)

    resampledData[:, chan] .= outputBuffer[thrID][newRate+1:end-newRate]
end