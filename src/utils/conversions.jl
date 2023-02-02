function samples2timeText(nSample::Int, srate::Float64)
    milisec = Millisecond(round((nSample / srate) * 1000))
    return Dates.canonicalize(milisec)
end

function samples2time(nSample::Int, srate::Float64)
    date = samples2timeText(nSample, srate)

    dts = [Day, Hour, Minute, Second, Millisecond]
    numbers = String[]

    for dt in dts
        val = findfirst(x -> typeof(x) == dt, date.periods)
        if val !== nothing
            push!(numbers, lpad(string(date.periods[val].value), 2, "0"))
        else
            push!(numbers, "00")
        end
    end
    numbers[end] = lpad(numbers[end], 3, "0")
    lables = ["DD", "HH", "MM", "SS", "mmm"]

    if numbers[1] == "00" && numbers[2] == "00"
        nStart = 3
    elseif numbers[1] == "00"
        nStart = 2
    else
        nStart = 1
    end
    return join(numbers[nStart:end-1], ":")*".$(numbers[end])"*
      " ($(join(lables[nStart:end-1], ":"))"*".$(lables[end]))"
end
