@unix_only begin
    run(`make libpicosat.so`)
end
@windows_only begin
    error("PicoSAT.jl does not currently work on Windows")
end
