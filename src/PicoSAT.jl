module PicoSAT

@unix_only begin
    const libpicosat = Pkg.dir("PicoSAT", "deps", "libpicosat.so")
end
@windows_only begin
    error("PicoSAT.jl does not currently work on Windows")
end

immutable PicoPtr
    ptr::Ptr{Void}
end
Base.convert(::Type{Ptr{Void}}, p::PicoPtr) = p.ptr
isnull(p::PicoPtr) = p.ptr == C_NULL

version()   = bytestring(ccall((:picosat_version, libpicosat), Ptr{Cchar}, ()))
config()    = bytestring(ccall((:picosat_config,  libpicosat), Ptr{Cchar}, ()))
copyright() = bytestring(ccall((:picosat_copyright, libpicosat), Ptr{Cchar}, ()))

# constructor
picosat_init() = ccall((:picosat_init, libpicosat), PicoPtr, ())

# destructor
picosat_reset(p::PicoPtr) = ccall((:picosat_reset, libpicosat), Void, (PicoPtr,), p)

# Measure all time spent in all calls in the solver.  By default only the
# time spent in 'picosat_sat' is measured.  Enabling this function might
# for instance triple the time needed to add large CNFs, since every call
# to 'picosat_add' will trigger a call to 'getrusage'.

picosat_measure_all_calls(p::PicoPtr) =
    ccall((:picosat_measure_all_calls, libpicosat), Void, (PicoPtr,), p)

# Set the prefix used for printing verbose messages and statistics.
# (Default is "c ")

picosat_set_prefix(p::PicoPtr, str::ByteString) =
    ccall((:picosat_set_prefix, libpicosat), Void, (PicoPtr,Ptr{Cchar}), p, str)

# Set verbosity level
# A verbosity level >= 1 prints more and more detailed progress reports to the output file.
# Verbose messages are prefixed with the string set by 'picosat_set_prefix'

picosat_set_verbosity(p::PicoPtr, level::Integer) =
    ccall((:picosat_set_verbosity, libpicosat), Void, (PicoPtr,Cint), p, level)

# Disable (set_plain == true) / Enable all prerocessing.

picosat_set_plain(v::Bool) =
    ccall((:picosat_set_plain, libpicosat), Void, (PicoPtr,Cint), v ? 1 : 0)

# If you know a good estimate on how many variables you are going to use
# then calling this function before adding literals will result in less
# resizing of the variable table.  But this is just a minor optimization.
# Beside exactly allocating enough variables it has the same effect as
# calling 'picosat_inc_max_var'.

picosat_adjust(p::PicoPtr, max_idx::Integer) =
    ccall((:picosat_adjust, libpicosat), Void, (PicoPtr,Cint), p, max_idx)

# As alternative to a decision limit you can use the number of propagations as limit.
# This is more linearly related to execution time. This has to
# be called after 'picosat_init' and before 'picosat_sat'.

picosat_set_propagation_limit(p::PicoPtr, limit::Integer) =
    ccall((:picosat_set_propagation_limit, libpicosat), Void, (PicoPtr,Culonglong), p, limit)

# Add a literal of the next clause.  A zero terminates the clause.  The
# solver is incremental.  Adding a new literal will reset the previous
# assignment.   The return value is the original clause index to which
# this literal respectively the trailing zero belong starting at 0.

picosat_add(p::PicoPtr, lit::Cint) =
    ccall((:picosat_add, libpicosat), Cint, (PicoPtr,Cint), p, lit)

# Call the main SAT solver.
# A negative decision limit sets no limit on the number of decisions.
picosat_sat(p::PicoPtr, limit::Int) =
    ccall((:picosat_sat, libpicosat), Cint, (PicoPtr,Cint), p, limit)

# p cnf <m> n
picosat_variables(p::PicoPtr) =
    ccall((:picosat_variables, libpicosat), Cint, (PicoPtr,), p)

# After 'picosat_sat' was called and returned 'PICOSAT_SATISFIABLE', then
# the satisfying assignment can be obtained by 'dereferencing' literals.
# The value of the literal is return as '1' for 'true',  '-1' for 'false'
# and '0' for an unknown value.

picosat_deref(p::PicoPtr) =
    ccall((:picosat_deref, libpicosat), Cint, (PicoPtr,), p)

add_clause(p::PicoPtr, clause) = begin
    for lit in clause
        v = convert(Cint, lit)
        v == 0 && throw(ErrorException("non zero integer expected"))
        picosat_add(p, v)
    end
    picosat_add(p, 0)
    return
end

add_clauses(p::PicoPtr, clauses) = begin
    for item in clauses
        add_clauses(p, item)
    end
    return
end

picosat_setup(clauses, vars::Integer, verbose::Integer, proplimit::Integer) = begin
    p = picosat_init()
    if isnull(p)
        picosat_reset(p)
        throw(ErrorException("failed to initialize PicoSAT library"))
    end
    if verbose < 0
        picosat_reset(p)
        throw(ArgumentError("verbose must be ≥ 0"))
    end
    picosat_set_verbosity(p, verbose)
    if vars != -1
        picosat_adjust(p, vars)
    end
    if proplimit < 0
        picosat_reset(p)
        throw(ArgumentError("proplimit must be ≥ 0"))
    end
    if proplimit > 0
        picosat_set_propagation_limit(p, proplimit)
    end
    try
        add_clauses(p, clauses)
    catch ex
        picosat_reset(p)
        rethrow(ex)
    end
    return p
end

get_solution(p::PicoPtr) = begin
    nvar = picosat_variables(p)
    if nvar <= 0
        picosat_reset(p)
        throw(ErrorException("number of solution variables ≤ 0"))
    end
    sol = zeros(Int, nvar)
    for i = 1:nvar
        v = picosat_dref(p, i)
        assert(v == 1 || v == -1)
        sol[i] = v
    end
    return sol
end

abstract SATResult

immutable Uknown <: SATResult
end

immutable Unsatisfiable <: SATResult
end

immutable Satisfiable <: SATResult
    result::Vector{Int}
end

# Solve the SAT problem for provided clauses
solve(clauses; vars=-1, verbose=0, proplimit=0) = begin
    p = picosat_setup(clauses, vars, verbose, proplimit)
    res = picosat_sat(p, -1)
    local result::SATResult
    if res == PICOSAT_SATISFIABLE
        result = Satisfiable(get_solution(p))
    elseif res == PICOSAT_UNSATISFIABLE
        result = Unsatisfiable()
    elseif res == PICOSAT_UKNOWN
        result = Unknown()
    else
        picosat_reset(p)
        throw(ErrorException("PicoSAT Errror: return value $res"))
    end
    picosat_reset(p)
    return result
end

end # module
