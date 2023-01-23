module Telepathy

using EEGIO
using DelimitedFiles
import UnicodePlots: scatterplot, scatterplot!
#using Mmap
using GLMakie
#using Makie.GeometryBasics
using Statistics
using StatsBase
#using CSV
#using DataFrames
using DSP
using FFTW
using LinearAlgebra

# For now, there is no clear benefit of having more threads in FFTW
# Setting this to 1, so there will be no interference with Julia threading
FFTW.set_num_threads(1)

include("types/components.jl")
include("types/EEG.jl")
export Raw

include("io/load_data.jl")
export load_data, parse_status!

include("io/events.jl")
export find_events!

include("channels/channels.jl")
export channel_names, get_channels, set_type!

include("channels/layout.jl")
export read_layout, set_layout!

include("viz/plot_layout.jl")
export plot_layout

include("viz/plot_raw.jl")

include("preprocessing/filter.jl")
export filter_data!

include("preprocessing/rereference.jl")
export get_reference, set_reference, set_reference!

include("preprocessing/resample.jl")
export resample!


# include("io/read_bdf.jl")
# export read_bdf, read_header
# include("io/ec_chan.jl")
# export set_montage, bdf_chans, modify_by_reference
# include("io/recognize_events.jl")
# export find_events, count_events, scatter_events, remove_channels
# include("io/bdf_resample.jl")
# export bdf_resample
# include("io/filters.jl")
# export notch_filter, highpass_filter, lowpass_filter, apply_lowpass_filter, apply_highpass_filter, apply_notch_filter
# include("viz/plot.jl")
# export plot
# include("viz/plotmontage.jl")
# export plotmontage

end # module
