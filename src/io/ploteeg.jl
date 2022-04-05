using BrainhackEEG
using GLMakie
data = read_bdf()
include("./ec_chan.jl")
set_montage()
f = Figure()
ax = Axis(f[1, 1])
points = [Point2f(x, y) for y in -5:5 for x in -5:5]
scatter!(ax,(0,0), markersize = 400, color = :white, strokewidth = 1, strokecolor = :black)
scatter!(ax,(points), markersize = 10, color = :white, strokewidth = 1, strokecolor = :red, overdraw=true)
display(f)