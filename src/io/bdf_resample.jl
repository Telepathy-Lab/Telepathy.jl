
function pad_vector(source_vector, pad)
    padded_vector = ones(length(source_vector)+2pad)
    for i in 1:pad
        padded_vector[i] = source_vector[1]
        padded_vector[pad+length(source_vector)+i] = source_vector[end]
    end
    for i in 1:length(source_vector)
        padded_vector[pad+i] = source_vector[i]
    end
    return padded_vector
end

function resample_vector(in_data, in_sample_rate, out_sample_rate)
    padded_data = pad_vector(in_data, 100)
    resample_factor = out_sample_rate / in_sample_rate
    r_padding = convert(Int64, ceil(100 * resample_factor))
    padded_out_data = resample(padded_data, resample_factor)
    k = convert(Int64, size(in_data)[1] * out_sample_rate / in_sample_rate) - 
        (length(padded_out_data)-2r_padding)
    return padded_out_data[r_padding+1:length(padded_out_data)-r_padding+k]
end

function bdf_resample(data::RawEEG, new_sample_rate)
    new_info = copy(data.info)
    no_channels = size(data.data)[2]
    new_info["sampRate"] = [new_sample_rate for i in 1:no_channels+1]
    new_info["nSampRec"] = [new_sample_rate for i in 1:no_channels+1]
    new_size = convert(Int64, size(data.data)[1] * new_sample_rate / data.info["sampRate"][1])
    new_data = Array{Float32}(undef, (new_size,no_channels))
    for channel in 1:no_channels
        new_data[:,channel] = resample_vector(data.data[:,channel], data.info["sampRate"][1],
                                              new_sample_rate)
    end
    file = RawEEG(new_info, new_data, data.status, data.lowTrigger, data.highVector, data.chans)
    return file
end