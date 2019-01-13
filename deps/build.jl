@static if Sys.isunix()
    @info("building release 965...")
    run(`make libpicosat.so`)
end

@static if Sys.iswindows()
    @error("PicoSAT.jl does not currently work on Windows")
end
