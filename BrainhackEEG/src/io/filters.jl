
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
