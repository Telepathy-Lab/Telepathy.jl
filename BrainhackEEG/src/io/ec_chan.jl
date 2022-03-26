function set_montage(data::RawEEG)
    df = CSV.read("./files/XYZ val.csv", DataFrame)
    # Assuming average head circumference is 56cm.
    chans = Dict(df[1,1] => (df[1,2], df[1,3], df[1,4]))
    x = 2
    for i in range(0,62)
        merge!(chans, Dict(df[x,1] => (df[x,2], df[x,3], df[x,4])))
        global x = x + 1
    end
    data.chans = chans

    return data
end

