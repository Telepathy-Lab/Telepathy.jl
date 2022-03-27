bdf_chans = [
    "Fp1" -27.525 84.713 -3.110;
    "AF7" -52.355 72.061 -3.110;
    "AF3" -36.207 77.647 24.567;
    "F1" -25.576 63.304 57.290;
    "F3" -48.575 59.985 44.563;
    "F5" -64.973 56.480 23.068;
    "F7" -72.061 52.355 -3.110;
    "FT7" -84.713 27.525 -3.110;
    "FC5" -79.135 30.377 27.542;
    "FC3" -60.283 32.053 57.290;
    "FC1" -33.397 33.397 75.584;
    "C1" -34.825 0.000 82.042;
    "C3" -64.112 0.000 61.913;
    "C5" -83.207 0.000 31.940;
    "T7" -89.072 0.000 -3.110;
    "TP7" -84.713 -27.525 -3.110;
    "CP5" -79.135 -30.377 27.542;
    "CP3" -60.283 -32.053 57.290;
    "CP1" -33.397 -33.397 75.584;
    "P1" -25.576 -63.304 57.290;
    "P3" -48.575 -59.985 44.563;
    "P5" -64.973 -56.480 23.068;
    "P7" -72.061 -52.355 -3.110;
    "P9" -65.349 -47.479 -37.667;
    "PO7" -52.355 -72.061 -3.110;
    "PO3" -36.207 -77.647 24.567;
    "O1" -27.525 -84.713 -3.110;
    "Iz" 0.000 -80.776 -37.667;
    "Oz" 0.000 -89.072 -3.110;
    "POz" 0.000 -83.207 31.940;
    "Pz" 0.000 -64.112 61.913;
    "CPz" 0.000 -34.825 82.042;
    "Fpz" 0.000 89.072 -3.110;
    "Fp2" 27.525 84.713 -3.110;
    "AF8" 52.355 72.061 -3.110;
    "AF4" 36.207 77.647 24.567;
    "Afz" 0.000 83.207 31.940;
    "Fz" 0.000 64.112 61.913;
    "F2" 25.576 63.304 57.290;
    "F4" 48.575 59.985 44.563;
    "F6" 64.973 56.480 23.068;
    "F8" 72.061 52.355 -3.110;
    "FT8" 84.713 27.525 -3.110;
    "FC6" 79.135 30.377 27.542;
    "FC4" 60.283 32.053 57.290;
    "FC2" 33.397 33.397 75.584;
    "FCz" 0.000 34.825 82.042;
    "Cz" 0.000 0.000 89.127;
    "C2" 34.825 0.000 82.042;
    "C4" 64.112 0.000 61.913;
    "C6" 83.207 0.000 31.940;
    "T8" 89.072 0.000 -3.110;
    "TP8" 84.713 -27.525 -3.110;
    "CP6" 79.135 -30.377 27.542;
    "CP4" 60.283 -32.053 57.290;
    "CP2" 33.397 -33.397 75.584;
    "P2" 25.576 -63.304 57.290;
    "P4" 48.575 -59.985 44.563;
    "P6" 64.973 -56.480 23.068;
    "P8" 72.061 -52.355 -3.110;
    "P10" 65.349 -47.479 -37.667;
    "PO8" 52.355 -72.061 -3.110;
    "PO4" 36.207 -77.647 24.567;
    "O2" 27.525 -84.713 -3.110;
]

function set_montage(data::RawEEG)
    df = DataFrame(bdf_chans, :auto)
    # Assuming average head circumference is 56cm.
    chans = Dict(df[1,1] => (df[1,2], df[1,3], df[1,4]))

    for i in 1:size(df)[1]
        merge!(chans, Dict(df[i,1] => (df[i,2], df[i,3], df[i,4])))
    end
    data.chans = chans

    return data
end

function modify_by_reference(data::RawEEG; reference_chan = ["average_of_all"])
    #we check if someone wants to see average signal of all electrodes as reference
    #reference_chan #the channel that will be reference
    if reference_chan == ["average_of_all"]
        reference_chan = []
        for element in 1:(Int(length(bdf_chans)/4))
            push!(reference_chan,bdf_chans[element])
        end
    end
    #we take list of all channels and turn them into lowercase strings
    elec_list_channels = String[]
    chanlabels_case = []
    for element in 1:length(data.info["chanLabels"])
        push!(chanlabels_case, lowercase(data.info["chanLabels"][element]))
    end
    #we take list of all channels in data that are electrodes and turn them into lowercase strings
    bdf_chans_case = String[]
    for element in 1:(Int(length(bdf_chans)/4))
        push!(bdf_chans_case,lowercase(bdf_chans[element]))
    end
    #we check which electrodes are in our data
    for element in chanlabels_case
        if element in bdf_chans_case
            push!(elec_list_channels, element)
        end
    end
    #we check indexes of electrodes in channels data
    no_chan = []
    for a in 1:length(elec_list_channels)
        push!(no_chan, findfirst(==(elec_list_channels[a]), chanlabels_case))
    end
    #we take input with reference electrode, convert it to lowercase, and return its col number in data
    #return ref_no_chain that is index of column that is going to be reference
    ref_no_chan = []

    for element in 1:(length(reference_chan))
        reference_chan_case = lowercase(reference_chan[element])
        push!(ref_no_chan, findfirst(==(reference_chan_case), chanlabels_case))
    end

    reference_col = data.data[:, ref_no_chan]
    #in each row we subtract value from reference columns 
    if length(ref_no_chan) >1
        aver = mean(reference_col, dims=2)
    else 
        aver = reference_col
    end
    new_data = copy(data.data)
    for i in 1:size(data.data)[2]
        if i in no_chan
            new_data[:,i] -= aver
        end
    end
    data.data = new_data
    return data
end