
"""
Notch filter for single signal vector.
By default filters out 50Hz power interference.
fs - sampling frequency of the input signal (defaults to 2048)
fw - frequency to be filtered out (defaults to 50Hz)
bw - bandwidth of the filter (default 0.12 works well for 50Hz power)
"""
function notch_filter(input_signal; fs=2048, fw=50, bw=0.12) 
    return filt(iirnotch(fw, bw; fs=fs), input_signal)
end

"""
Highpass filter for single signal vector.
fs - sampling frequency of the input signal (defaults to 2048)
fw - cutoff frequency
hw - hanning window (defaults to 511)
"""
function highpass_filter(input_signal, fw; fs=2048, hw=511)
    responsetype = Highpass(fw; fs=fs)
    designmethod = FIRWindow(hanning(hw))
    return filt(digitalfilter(responsetype, designmethod), input_signal)
end

"""
Lowpass filter for single signal vector.
fs - sampling frequency of the input signal (defaults to 2048)
fw - cutoff frequency
hw - hanning window (defaults to 128)
"""
function lowpass_filter(input_signal, fw; fs=2048, hw=128)
    responsetype = Lowpass(fw; fs=fs)
    designmethod = FIRWindow(hanning(hw))
    return filt(digitalfilter(responsetype, designmethod), input_signal)
end

"""
Applies lowpass filter to the whole dataset.
Returns new dataset with transformed data.
"""
function apply_lowpass_filter(data::RawEEG, prog; hw=511)
    fs = data.info["sampRate"][1]
    no_channels = size(data.data)[2]
    no_samples = size(data.data)[1]
    new_signals = Array{Float32}(undef, (no_samples,no_channels))
    for channel in 1:no_channels
        new_signals[:,channel] = lowpass_filter(data.data[:,channel], prog, fs=fs, hw=hw)
    end
    new_data = RawEEG(data.info, new_signals, data.status, data.lowTrigger, data.highVector, data.chans)
    return new_data
end