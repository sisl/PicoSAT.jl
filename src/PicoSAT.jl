module PicoSAT

export solve, itersolve, satisfiable

@unix_only begin
    const libpicosat = Pkg.dir("PicoSAT", "deps", "libpicosat.so")
end
@windows_only begin
    error("PicoSAT.jl does not currently work on Windows")
end

const UNKNOWN = 0
const SATISFIABLE = 10
const UNSATISFIABLE = 20

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

picosat_add(p::PicoPtr, lit::Integer) =
    ccall((:picosat_add, libpicosat), Cint, (PicoPtr,Cint), p, lit)

# Call the main SAT solver.
# A negative decision limit sets no limit on the number of decisions.
picosat_sat(p::PicoPtr, limit::Integer) =
    ccall((:picosat_sat, libpicosat), Cint, (PicoPtr,Cint), p, limit)

# p cnf <m> n
picosat_variables(p::PicoPtr) =
    ccall((:picosat_variables, libpicosat), Cint, (PicoPtr,), p)

# After 'picosat_sat' was called and returned 'PICOSAT_SATISFIABLE', then
# the satisfying assignment can be obtained by 'dereferencing' literals.
# The value of the literal is return as '1' for 'true',  '-1' for 'false'
# and '0' for an unknown value.

picosat_deref(p::PicoPtr, lit::Integer) =
    ccall((:picosat_deref, libpicosat), Cint, (PicoPtr,Cint), p, lit)

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
        add_clause(p, item)
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
    if nvar < 0
        picosat_reset(p)
        throw(ErrorException("number of solution variables < 0"))
    end
    sol = zeros(Int, nvar)
    for i = 1:nvar
        v = picosat_deref(p, i)
        assert(v == 1 || v == -1)
        sol[i] = v * i
    end
    return sol
end

# Solve the SAT problem for provided clauses
function solve(clauses;
               vars::Integer=-1,
               verbose::Integer=0,
               proplimit::Integer=0)
    p = picosat_setup(clauses, vars, verbose, proplimit)
    res = picosat_sat(p, -1)
    if res == SATISFIABLE
        result = get_solution(p)
    elseif res == UNSATISFIABLE
        result = :unsatisfiable
    elseif res == UNKNOWN
        result = :unknown
    else
        picosat_reset(p)
        throw(ErrorException("PicoSAT Errror: return value $res"))
    end
    picosat_reset(p)
    return result
end

type PicoSolIterator
    ptr::PicoPtr
    vars::Vector{Int}

    PicoSolIterator(p::PicoPtr) = begin
        @assert !isnull(p)
        iter = new(p, Int[])
        finalizer(iter, i -> picosat_reset(i.ptr))
        return iter
    end
end

function itersolve(clauses;
                   vars::Integer=-1,
                   verbose::Integer=0,
                   proplimit::Integer=0)
    p = picosat_setup(clauses, vars, verbose, proplimit)
    return PicoSolIterator(p)
end

# Add inverse of current solution to the clauses
blocksol(it::PicoSolIterator) = begin
    nvar = picosat_variables(it.ptr)
    if nvar < 0
        throw(ErrorException("number of solution variables < 0"))
    end
    if length(it.vars) < nvar
        resize!(it.vars, nvar)
    end
    for i = 1:nvar
        it.vars[i] = picosat_deref(it.ptr, i) > 0 ? 1 : -1
    end
    for i = 1:nvar
        picosat_add(it.ptr, it.vars[i] < 0 ? i : -i)
    end
    picosat_add(it.ptr, 0)
    return
end

next_solution(it::PicoSolIterator) = begin
    res = picosat_sat(it.ptr, -1)
    if res == SATISFIABLE
        result = get_solution(it.ptr)
        # add inverse sol for next iter
        blocksol(it)
    elseif res == UNSATISFIABLE
        result = :unsatisfiable
    elseif res == UNKNOWN
        result = :unknown
    else
        throw(ErrorException("PicoSAT Errror: return value $res"))
    end
    return result
end

satisfiable(sol) = sol !== :unknown && sol !== :unsatisfiable

Base.start(it::PicoSolIterator) = begin
    sol = next_solution(it)
    (sol, satisfiable(sol))
end
Base.done(it::PicoSolIterator, state) = state[2] == false

Base.next(it::PicoSolIterator, state) = begin
    sol = next_solution(it)
    (state[1], (sol, satisfiable(sol)))
end

end # module
