function resample!(raw::Raw, newSrate::Int; type=:FFT)

    # Pick only EEG data for resampling
    # Other channels are assumed to be digital and will be decimated
    chansEEG = get_channels(raw, :EEG)
    oldSrate = raw.chans.srate[1]
    sRatio = oldSrate / newSrate
    oldLength = size(raw.data, 1)
    newLength = Int(oldLength*newSrate/oldSrate)

    # Preallocate an array for resampled data
    resampledData = zeros(Float32, newLength, size(raw.data,2))

    if type == :FFT
        resample!(raw, resampledData, chansEEG, sRatio, oldLength, newLength)
    elseif type == :POLY
        @warn "Polyphase filter resampling is not yet implemented!"
    end
    return resampledData
end

function resample!(raw::Raw, resampledData, chansEEG, sRatio, oldLength, newLength)
    fftLength = sRatio > 1 ? oldLength+1 : newLength +1

    nThr = Threads.nthreads()

    inputBuffer = [zeros(Float32, oldLength*2) for i in 1:nThr]
    fftBuffer = [zeros(ComplexF32, fftLength) for i in 1:nThr]
    outputBuffer = [zeros(Float32, newLength*2) for i in 1:nThr]
    
    @views inputBuffer[1][1:oldLength] .= raw.data[:, chansEEG[1]]
    @views inputBuffer[1][end:-1:oldLength+1] .= raw.data[:, chansEEG[1]]
    
    rfftPlan = plan_rfft(inputBuffer[1])
    irfftPlan = plan_irfft(fftBuffer[1][1:newLength+1], newLength*2)
        
    @views dataSubarray = raw.data[:,chansEEG]
    Threads.@threads for chan in axes(dataSubarray, 2)
    #for chan in axes(dataSubarray, 2)
        thrID = Threads.threadid()
        #@info chan, thrID
        resample_channel!(inputBuffer[thrID], fftBuffer[thrID], outputBuffer[thrID], 
        raw, chan, resampledData, rfftPlan, irfftPlan, oldLength, newLength, sRatio)
    end
end

function resample_channel!(inputBuffer, fftBuffer, outputBuffer, raw, chan, resampledData, rfftPlan, irfftPlan, oldLength, newLength, sRatio)
    @views begin
        inputBuffer[1:oldLength] .= raw.data[:, chan]
        inputBuffer[end:-1:oldLength+1] .= raw.data[:, chan]

        mul!(fftBuffer[1:oldLength+1], rfftPlan, inputBuffer)
        mul!(outputBuffer, irfftPlan, fftBuffer[1:newLength+1])

        resampledData[:, chan] .= outputBuffer[1:newLength] ./ sRatio
    end
end

# function DSP.resample(raw::Raw, srate::Int)
#     println("yes")
# end

