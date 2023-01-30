Base.@kwdef mutable struct Options
    threading::Bool = false
    nThreads::Int = Threads.nthreads()
end