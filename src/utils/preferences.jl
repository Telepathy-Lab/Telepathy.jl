Base.@kwdef mutable struct Options
    threading::Bool = false
    nThreads::Int = Threads.nthreads()
end

function Base.show(io::IO, ::MIME"text/plain", opts::Options)
    println(io, "Telepathy options:")
    println(io, "  threading: $(opts.threading)")
    println(io, "  nThreads: $(opts.nThreads)")
end