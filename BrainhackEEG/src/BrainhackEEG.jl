module BrainhackEEG

using Mmap
using GLMakie
using Makie.GeometryBasics
using Statistics
using CSV
using DataFrames
using DSP

include("io/read_bdf.jl")
export read_bdf, read_header, RawEEG
include("io/ec_chan.jl")
export set_montage, bdf_chans, modify_by_reference
include("io/recognize_events.jl")
export find_events, count_events, scatter_events, remove_channels
include("io/bdf_resample.jl")
export bdf_resample
include("io/filters.jl")
export notch_filter, highpass_filter, lowpass_filter, apply_lowpass_filter, apply_highpass_filter, apply_notch_filter
include("viz/plot.jl")
export plot
include("viz/plotmontage.jl")
export plotmontage

end # module
