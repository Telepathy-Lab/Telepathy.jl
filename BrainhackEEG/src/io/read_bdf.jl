function read_bdf(filename::AbstractString)
    
    fid = open(filename, "r")
    
    info = read_header(fid)
    
    data, status, lowTrigger, highTrigger = read_data(fid, info)

    close(fid)
    
    file = RawEEG(info, data, status, lowTrigger, highTrigger)
    
    return file
end


function read_header(fid::IO)
    
    info = Dict{String,Any}(
                "idCodeNonASCII" => Int32(read(fid, UInt8)),
                "idCode" => decodeString(fid, 7),
                "subID" => decodeString(fid, 80),
                "recID" => decodeString(fid, 80),
                "startDate" => decodeString(fid, 8),
                "startTime" => decodeString(fid, 8),
                "nBytes" => decodeNumber(fid, 8),
                "versionDataFormat" => decodeString(fid, 44),
                "nDataRecords" => decodeNumber(fid, 8),
                "recordDuration" => decodeNumber(fid, 8),
                "nChannels" => decodeNumber(fid, 4),
    )
    
    info["chanLabels"] = decodeChanStrings(fid, info["nChannels"], 16)
    info["transducer"]  = decodeChanStrings(fid, info["nChannels"], 80)
    info["physDim"] = decodeChanStrings(fid, info["nChannels"], 8)
    info["physMin"] = decodeChanNumbers(fid, info["nChannels"], 8)
    info["physMax"] = decodeChanNumbers(fid, info["nChannels"], 8)
    info["digMin"] = decodeChanNumbers(fid, info["nChannels"], 8)
    info["digMax"] = decodeChanNumbers(fid, info["nChannels"], 8)
    info["prefilt"] = decodeChanStrings(fid, info["nChannels"], 80)
    info["nSampRec"] = decodeChanNumbers(fid, info["nChannels"], 8)
    info["reserved"] = decodeChanStrings(fid, info["nChannels"], 32)
    info["scaleFactor"] = Float32.(info["physMax"]-info["physMin"])./(info["digMax"]-info["digMin"])
    info["sampRate"] = info["nSampRec"] / info["recordDuration"]
    
    return info
end

function read_data(fid::IO, info::Dict{String,Any})
    
    srate = Int64(info["sampRate"][1])
    duration = info["nDataRecords"]
    nChannels = info["nChannels"]
    scaleFactor = info["scaleFactor"]
    chanLabels = info["chanLabels"]
    #raw = read!(fid, Array{UInt8}(undef, 3*duration*nChannels*srate));
    raw = Mmap.mmap(fid);
    data = Array{Float32}(undef, (srate*duration,nChannels-1));
    status = Vector{Float32}(undef, srate*duration)
    lowTrigger = Vector{Float32}(undef, srate*duration)
    highTrigger = Vector{Float32}(undef, srate*duration)
    
    convert_binary(raw, data, status, lowTrigger, highTrigger, srate, duration, nChannels, scaleFactor, chanLabels)

    return data, status, lowTrigger, highTrigger
end

function convert_binary(raw::Array{UInt8}, data::Array{Float32}, status::Vector{Float32}, lowTrigger::Vector{Float32}, highTrigger::Vector{Float32}, 
                         srate::Int64, duration::Int64, nChannels::Int64, scaleFactor::Vector{Float32}, chanLabels::Vector{String})
    Threads.@threads for record=1:duration
        for chan=1:(nChannels-1)
            for dataPoint=1:srate
                sample = (record-1)*nChannels*srate + (chan-1)*srate + dataPoint-1
                @inbounds data[dataPoint+(record-1)*srate,chan] = (((Int32(raw[3*sample+1]) << 8) | 
                                                                    (Int32(raw[3*sample+2]) << 16) | 
                                                                    (Int32(raw[3*sample+3]) << 24)) >> 8) * scaleFactor[chan]
            end
        end
        for dataPoint=1:srate
            sample = (record-1)*nChannels*srate + (nChannels-1)*srate + dataPoint-1
            @inbounds lowTrigger[dataPoint+(record-1)*srate] = Int32(raw[3*sample+1]) * scaleFactor[nChannels]
            @inbounds highTrigger[dataPoint+(record-1)*srate] = Int32(raw[3*sample+2]) * scaleFactor[nChannels]
            @inbounds status[dataPoint+(record-1)*srate] = Int32(raw[3*sample+3])  * scaleFactor[nChannels]

        end
    end
end

decodeString(fid::IO, size::Int) = ascii(String(read!(fid, Array{UInt8}(undef, size))))

decodeNumber(fid::IO, size::Int) = parse(Int, ascii(String(read!(fid, Array{UInt8}(undef, size)))))

function decodeChanStrings(fid::IO, nChannels::Int, size::Int)
    arr = Array{String}(undef, nChannels)
    buf = read(fid, nChannels*size)
    for i=1:nChannels
        @inbounds arr[i] = strip(ascii(String(buf[(size*(i-1)+1):(size*(i-1)+size)])))        
    end
    return arr
end

function decodeChanNumbers(fid::IO, nChannels::Int, size::Int)
    arr = Array{Int}(undef, nChannels)
    buf = read(fid, nChannels*size)
    for i=1:nChannels
        @inbounds arr[i] = parse(Int, ascii(String(buf[(size*(i-1)+1):(size*(i-1)+size)])))
    end
    return arr
end

mutable struct RawEEG
    info::Dict
    data::Array
    status::Vector
    lowTrigger::Vector
    highVector::Vector
    chans:: Dict
end

function print_test()
    println("BLablablabla")
end