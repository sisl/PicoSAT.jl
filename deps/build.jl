version = v"0.6.1" 
target  = "libpicosat.$(Sys.dlext)"

@unix_only begin
    run(`make libpicosat.so`)
end
