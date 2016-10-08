@static if is_unix()
    run(`make libpicosat.so`)
end
@static if is_windows()
    error("PicoSAT.jl does not currently work on Windows")
end
