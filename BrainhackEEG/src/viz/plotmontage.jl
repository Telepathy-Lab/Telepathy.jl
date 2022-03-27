function plotmontage(data::RawEEG)
    set_montage(data)
    f = Figure(resolution=(800,800))
    ax = Axis(f[1, 1], aspect=1)
    poly!(Point2f[(-10,90), (10,90), (0, 100)], color = :white, strokecolor = :black, strokewidth = 1)
    poly!(Circle(Point2f(0, 0), 90), color = :white, strokewidth = 1, strokecolor = :black)
    for i in data.chans
        t=(((100-i[2][3])/100)^-0.5)*1.1
        scatter!(ax, ((i[2][1])/t, i[2][2]/t), markersize = 8, color = :white, strokewidth = 1, strokecolor = :red, overdraw=true)
        text!(i[1], position = (i[2][1]/t, i[2][2]/t), overdraw=true, textsize=15, offset = (-20, 5))
    end
    display(f)
end