#= 
    Code to manage threading for applicable data processing functions.
    It tries to achive two goals:
    - Manage even distribution of load for each thread, while allowing for some flexibility. 
    This is heavily inspired by ChunkSplitters.jl package (https://github.com/m3g/ChunkSplitters.jl).
    - Manage the use of multiple threads per each function. This means acknowledging a global
    setting for the package, individual settings for every function call, and running code
    on smaller number of threads then available maximum. This is done trough a function inspired
    by a thread on dicourse https://discourse.julialang.org/t/optional-macro-invocation/18588/21
    and the response of user tkf. For now I found it too complicated to implement it as a macro,
    since it would require making a nested loop out of a single one inside the macro and this
    does not want to play nicely. I will try to implement it as a macro in the future.
=#
"""
    batch(collection, nBatch::Int; spread=true)

Internal function helping to partition a collection into batches for processing by separate
threads. Heavily inspired by ChunkSplitters.jl package, but modified to better fit the needs
of this package (collections can be vectors of indices or ranges, returns an enumerated
generator, that will help in buffer creation for multithreading processing).

##### Arguments
- `collection`: Indexable object which elements indicate what should be passed to function
in a thread. Typical uses in `Telepathy` include indices of channels to apply a function to,
set of parameters to swap during function execution, etc.
- `nBatch::Int`: Number of batches to generate. In combination with `setup_workers` function
controls how many threads will be spawn during code execution (if the number is lower than 
`Threads.nthreads()`, otherwise the actual number of threads is decided elsewhere).

##### Keyword arguments
- `spread::Bool=true`: Allows to choose between giving N adjacent elements of collection to
each thread and giving each thread elements from collection spaced by nBatch elements.

##### Returns
- Enumerate_generator::Tuple(Int, typeof(collection)): Function returns an enumerate generator.
First element of the tuple indicates the number of the batch (which can be useful for e.g.
indexing into dedicated objects, like buffers, from inside the threads).
Second elements is a subset of collection to be handed to the thread of the same type as
collection on the input.

##### Examples
```@repl
# Divide 23 elements between 4 batches with spread.
batch(1:23, 4)
```
```@repl
# Divide 11 elements between 4 batches without spread.
batch([1,2,3,4,5,6,7,8,9,10,11], 4, spread=false)
```
"""
function batch(collection, nBatch::Int; spread=true)
    elem = length(collection)

    if nBatch > elem
        nBatch = elem
    end

    (bSize, bRem) = divrem(elem, nBatch)

    if spread
        batches = Iterators.map(x->collection[x:nBatch:elem], 1:nBatch)
    else
        tmp = Iterators.map(
            x -> x > bRem ? 
            (bRem*(bSize+1)).+ (((x-bRem-1)*bSize+1):(x-bRem)*bSize) :
            ((x-1)*(bSize+1)).+(1:1+bSize),
            1:nBatch)
        batches = Iterators.map(x -> collection[x], tmp)
    end
    return Iterators.enumerate(batches)
end

# TODO: We could get rid of collect if we used Floops.jl, but for now I want to stay with Base.
function setup_workers(collection, nThreads; spread=true)
    if !options.threading
        nBatch = 1
    elseif nThreads == 0
        nBatch = options.nThreads
    elseif nThreads < 0
        throw(ArgumentError("Number of threads must be positive or zero for all available threads."))
    else
        nBatch = nThreads
    end

    return collect(batch(collection, nBatch, spread=spread))
end