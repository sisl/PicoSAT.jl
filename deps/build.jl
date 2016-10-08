@static if is_unix()
    info("building release 965...")
    run(`make libpicosat.so`)
end
@static if is_windows()
    error("PicoSAT.jl does not currently work on Windows")
end
