target  = "libpicosat.$(Sys.dlext)"

@unix_only begin
    run(`make libpicosat.so`)
end
