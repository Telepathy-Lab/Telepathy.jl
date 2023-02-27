module Telepathy

# For development purposes

import Pkg
using Dates
using EEGIO
using DelimitedFiles
import UnicodePlots: scatterplot, scatterplot!
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
include("viz/plot_filter.jl")
export plot_filter

include("preprocessing/filter.jl")
export filter_data, filter_data!, design_filter

include("preprocessing/rereference.jl")
export get_reference, set_reference, set_reference!

include("preprocessing/resample.jl")
export resample, resample!

include("viz/plot_layout.jl")
export plot_layout

include("viz/plot_raw.jl")
include("viz/plot_filter.jl")
export plot_filter

include("viz/plot_events.jl")
export plot_events

include("utils/threading.jl")
include("utils/preferences.jl")
include("utils/conversions.jl")
include("utils/helpers.jl")

# TODO: Handle options with Preferences.jl
options = Options()


end # module
