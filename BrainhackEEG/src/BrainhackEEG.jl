module BrainhackEEG

using Mmap
using GLMakie
using Statistics
using CSV
using DataFrames
using DSP

include("io/read_bdf.jl")
export read_bdf, read_header, RawEEG, bdf_resample
include("./io/ec_chan.jl")
export set_montage

include("viz/plot.jl")
export plot


end # module
