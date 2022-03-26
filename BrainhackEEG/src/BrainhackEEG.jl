module BrainhackEEG

using Mmap
using GLMakie
using Statistics

include("io/read_bdf.jl")
export read_bdf, read_header, RawEEG

include("viz/plot.jl")
export plot


end # module
