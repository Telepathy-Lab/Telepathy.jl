function parse_pkg_status(package::String)
    buff = IOBuffer()
    Pkg.status(package, io=buff)
    status = String(take!(buff))
    status = split(status, [' ', '\n'])
    if (length(status) < 8) & ("Matches" in status)
        return "Not installed"
    else
        status = status[findfirst(x -> startswith(x, "v"), status)]
        return strip(status)
    end
end

function parse_blas_backend()
    for library in BLAS.get_config().loaded_libs
        if contains(library.libname, "openblas")
            return "OpenBLAS"
        elseif contains(library.libname, "mkl")
            return "MKL"
        elseif contains(library.libname, "accelerate")
            return "Accelerate"
        elseif contains(library.libname, "blis")
            return "BLIS"
        elseif contains(library.libname, "fujitsu")
            return "FujitsuBLAS"
        end
    end
end

function print_pkg_versions(packages::Vector{String})
    for package in packages
        vers = parse_pkg_status(package)

        nameLen = length(package)
        println("$package $("."^(22-nameLen)) $vers")
    end
end

function info()
    # Adapted from versioninfo() in Base, which only prints the information.
    printstyled("System information\n", color=38)
    printstyled("Julia Version", color=41)
    println(" ......... $(VERSION)")

    # System information
    system = ""
    if Sys.islinux()
        try system = readchomp(pipeline(`lsb_release -ds`, stderr=devnull)); catch; end
    end
    if Sys.iswindows()
        try system = strip(read(`$(ENV["COMSPEC"]) /c ver`, String)); catch; end
    end
    if Sys.isunix()
        try system = readchomp(`uname -mprsv`); catch; end
    end

    printstyled("Platform", color=41)
    println(" .............. $(system)")
    println("")

    cpu = Sys.cpu_info()
    printstyled("CPU", color=41)
    println(" ................... ", length(cpu), " × ", cpu[1].model)
    printstyled("Threads", color=41)
    println(" ............... ")
    println(lpad("Julia: ", 24), Threads.maxthreadid(), "\t(on ", Sys.CPU_THREADS, " virtual cores)")
    println(lpad("BLAS: ", 24), BLAS.get_num_threads(), "\t($(parse_blas_backend()))")
    println(lpad("FFTW: ", 24), FFTW.get_num_threads())
    println("")

    printstyled("Memory", color=41)
    println(" ................ $(round(Sys.total_memory() / 2^30, digits=2)) GB")
    println("")
    
    print_pkg_versions(["Telepathy", "EEGIO"])
    println("")
    print_pkg_versions(["DSP", "FFTW"])
    println("")
    print_pkg_versions(["UnicodePlots","GLMakie"])

    return nothing
end

function print_ansi_colors()
    for i in 1:16
        for j in 1:16
            num = (i-1)*16 + j - 1
            nums = lpad(string(num), 3, "0")
            nums = lpad(nums, 4, " ")
            nums = rpad(nums, 5, " ")
            printstyled("$nums", reverse=true, color=num)
        end
        println()
    end
end
