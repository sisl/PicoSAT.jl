module PicoSAT

export solve, itersolve

import Base: convert, iterate, IteratorSize

@static if Sys.isunix()
    const libpicosat = joinpath(dirname(@__FILE__), "..", "deps", "libpicosat.so")
end
@static if Sys.iswindows()
    throw(ErrorException("PicoSAT.jl does not currently work on Windows"))
end

const UNKNOWN = 0
const SATISFIABLE = 10
const UNSATISFIABLE = 20

struct PicoPtr
    ptr::Ptr{Cvoid}
end
convert(::Type{Ptr{Cvoid}}, p::PicoPtr) = p.ptr

version()   = bytestring(ccall((:picosat_version, libpicosat), Ptr{Cchar}, ()))
config()    = bytestring(ccall((:picosat_config,  libpicosat), Ptr{Cchar}, ()))
copyright() = bytestring(ccall((:picosat_copyright, libpicosat), Ptr{Cchar}, ()))

# constructor
picosat_init() = ccall((:picosat_init, libpicosat), PicoPtr, ())

# destructor
picosat_reset(p::PicoPtr) = ccall((:picosat_reset, libpicosat), Cvoid, (PicoPtr,), p)

"""
Measure all time spent in all calls in the solver.  By default only the
time spent in 'picosat_sat' is measured.  Enabling this function might
for instance triple the time needed to add large CNFs, since every call
to 'picosat_add' will trigger a call to 'getrusage'.
"""
picosat_measure_all_calls(p::PicoPtr) =
    ccall((:picosat_measure_all_calls, libpicosat), Cvoid, (PicoPtr,), p)

"""
Set the prefix used for printing verbose messages and statistics.
(Default is "c ")
"""
picosat_set_prefix(p::PicoPtr, str::String) =
    ccall((:picosat_set_prefix, libpicosat), Cvoid, (PicoPtr,Ptr{Cchar}), p, str)

"""
Set verbosity level
A verbosity level >= 1 prints more and more detailed progress reports to the output file.
Verbose messages are prefixed with the string set by 'picosat_set_prefix'
"""
picosat_set_verbosity(p::PicoPtr, level::Integer) =
    ccall((:picosat_set_verbosity, libpicosat), Cvoid, (PicoPtr,Cint), p, level)

"""
Disable (set_plain == true) / Enable all prerocessing.
"""
picosat_set_plain(p::PicoPtr, v::Bool) =
    ccall((:picosat_set_plain, libpicosat), Cvoid, (PicoPtr,Cint), p, v ? 1 : 0)

"""
If you know a good estimate on how many variables you are going to use
then calling this function before adding literals will result in less
resizing of the variable table.  But this is just a minor optimization.
Beside exactly allocating enough variables it has the same effect as
calling 'picosat_inc_max_var'.
"""
picosat_adjust(p::PicoPtr, max_idx::Integer) =
    ccall((:picosat_adjust, libpicosat), Cvoid, (PicoPtr,Cint), p, max_idx)

"""
As alternative to a decision limit you can use the number of propagations as limit.
This is more linearly related to execution time. This has to
be called after 'picosat_init' and before 'picosat_sat'.
"""
picosat_set_propagation_limit(p::PicoPtr, limit::Integer) =
    ccall((:picosat_set_propagation_limit, libpicosat), Cvoid, (PicoPtr,Culonglong), p, limit)

"""
Add a literal of the next clause.  A zero terminates the clause.  The
solver is incremental.  Adding a new literal will reset the previous
assignment.   The return value is the original clause index to which
this literal respectively the trailing zero belong starting at 0.
"""
picosat_add(p::PicoPtr, lit::Integer) =
    ccall((:picosat_add, libpicosat), Cint, (PicoPtr,Cint), p, lit)

"""
Call the main SAT solver.
A negative decision limit sets no limit on the number of decisions.
"""
picosat_sat(p::PicoPtr, limit::Integer) =
    ccall((:picosat_sat, libpicosat), Cint, (PicoPtr,Cint), p, limit)

"""p cnf <m> n"""
picosat_variables(p::PicoPtr) =
    ccall((:picosat_variables, libpicosat), Cint, (PicoPtr,), p)

"""
After 'picosat_sat' was called and returned 'PICOSAT_SATISFIABLE', then
the satisfying assignment can be obtained by 'dereferencing' literals.
The value of the literal is return as '1' for 'true',  '-1' for 'false'
and '0' for an unknown value.
"""
picosat_deref(p::PicoPtr, lit::Integer) =
    ccall((:picosat_deref, libpicosat), Cint, (PicoPtr,Cint), p, lit)

function add_clause(p::PicoPtr, clause)
    for lit in clause
        v = convert(Cint, lit)
        v == 0 && throw(ErrorException("PicoSAT Error: non zero integer expected"))
        picosat_add(p, v)
    end
    picosat_add(p, 0)
    return
end

function add_clauses(p::PicoPtr, clauses)
    for item in clauses
        add_clause(p, item)
    end
    return
end

function picosat_setup(clauses, vars::Integer, verbose::Integer, proplimit::Integer)
    p = picosat_init()
    if p.ptr === C_NULL
        picosat_reset(p)
        throw(ErrorException("PicoSAT Error: failed to initialize PicoSAT library"))
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

function get_solution(p::PicoPtr)
    nvar = picosat_variables(p)
    if nvar < 0
        picosat_reset(p)
        throw(ErrorException("number of solution variables < 0"))
    end
    sol = zeros(Int, nvar)
    for i = 1:nvar
        v = picosat_deref(p, i)
        @assert(v == 1 || v == -1)
        sol[i] = v * i
    end
    return sol
end
"""
`solve(clauses; vars::Integer=-1, verbose::Integer=0, proplimit::Integer=0)`
   - `vars` - the number of variables
   - `verbose` - prints solver logs to `STDOUT` when `verbose > 0` with increasing detail.
   - `proplimit` - helps to bound the execution time.  The number of propagations and the solution time are roughly linearly related.  A value of 0 (default) allows for an unbounded number of propagations.

Returns a solution if the problem is satisfiable.
Satisfiable solutions are represented as a vector of signed integers.
If the problem is not satisfiable the method returns an `:unsatisfiable` symbol.
If a solution cannot be found within the defined propagation limit, an `:unknown` symbol is returned.
```julia
julia> import PicoSAT
julia> cnf = Any[[1, -5, 4], [-1, 5, 3, 4], [-3, -4]];
julia> PicoSAT.solve(cnf)
5-element Array{Int64,1}:
   1
  -2
  -3
  -4
   5
```
"""
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
        throw(ErrorException("PicoSAT Error: return value $res"))
    end
    picosat_reset(p)
    return result
end

mutable struct PicoSolIterator
    ptr::PicoPtr
    vars::Vector{Int}

    function PicoSolIterator(p::PicoPtr)
        @assert p.ptr !== C_NULL
        iter = new(p, Int[])
        finalizer(i -> picosat_reset(i.ptr), iter)
        return iter
    end
end
"""
`itersolve(clauses; vars::Integer=-1, verbose::Integer=0, proplimit::Integer=0)`
   - `vars` - the number of variables
   - `verbose` - prints solver logs to `STDOUT` when `verbose > 0` with increasing detail.
   - `proplimit` - helps to bound the execution time.  The number of propagations and the solution time are roughly linearly related.  A value of 0 (default) allows for an unbounded number of propagations.


Returns an iterable object over all solutions.
When a user-defined propagation limit is specified, the iterator may not produce all feasible solutions.

```julia
julia> import PicoSAT
julia> cnf = Any[[1, -5, 4], [-1, 5, 3, 4], [-3, -4]];
julia> PicoSAT.itersolve(cnf)
julia> for sol in PicoSAT.itersolve(cnf)
           println(sol)
       end
[1,-2,-3,-4,5]
[1,-2,-3,4,-5]
[1,-2,-3,4,5]
[1,-2,3,-4,-5]
...
```
"""
function itersolve(clauses;
                   vars::Integer=-1,
                   verbose::Integer=0,
                   proplimit::Integer=0)
    p = picosat_setup(clauses, vars, verbose, proplimit)
    return PicoSolIterator(p)
end

# Add inverse of current solution to the clauses
function blocksol(it::PicoSolIterator)
    nvar = picosat_variables(it.ptr)
    if nvar < 0
        throw(ErrorException("PicoSAT Error: number of solution variables < 0"))
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

function next_solution(it::PicoSolIterator)
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

function Base.iterate(it::PicoSolIterator, state=nothing)
    sol = next_solution(it)
    if satisfiable(sol)
        return (sol, nothing)
    else
        return nothing
    end
end

IteratorSize(it::PicoSolIterator) = Base.SizeUnknown()
end # module
