# PicoSAT.jl

[![Build Status](https://travis-ci.org/jakebolewski/PicoSAT.jl.svg?branch=master)](https://travis-ci.org/jakebolewski/PicoSAT.jl)
[![Coverage Status](https://img.shields.io/coveralls/jakebolewski/PicoSAT.jl.svg)](https://coveralls.io/r/jakebolewski/PicoSAT.jl)

PicoSAT.jl provides [Julia](www.julialang.org) bindings to the popular [SAT](http://en.wikipedia.org/wiki/Boolean_satisfiability_problem) solver [picosat](http://fmv.jku.at/picosat/) by Armin Biere.  It is based off the Python [pycosat](https://github.com/ContinuumIO/pycosat) and Go [pigosat](https://github.com/wkschwartz/pigosat) bindings written by Ilan Schnell and Willam Schwartz.

## Installation

To install, run `Pkg.add("PicoSAT")` in Julia.  The entire picosat library (v960) is shipped with the package to make building the library easier.  Windows builds are currently not supported at the moment.

# Usage
The `PicoSAT` module exports two functions `solve` and `itersolve`.  Both functions take an iterable of clauses as a required argument.  Each clause is represented as an iterable of non-zero integers.

Both methods take the following optional keyword arguments:
   - `vars` - the number of variables
   - `verbose` - prints solver logs to `STDOUT` when `verbose > 0` with increasing detail.
   - `proplimit` - helps to bound the execution time.  The number of propagations and the solution time are roughly linearly related.  A value of 0 (default) allows for an unbounded number of propagations.

`solve(clauses; vars::Integer=-1, verbose::Integer=0, proplimit::Integer=0)`
 - Returns a solution if the problem is satisfiable.  Satisfiable solutions are represented as a vector of signed integers.  If the problem is not satisfiable the method returns an `:unsatisfiable` symbol.  If a solution cannot be found within the defined propagation limit, an `:unknown` symbol is returned.

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

The absolute values of the solution vector represent the ith variable.  The sign of the ith variable represents the boolean values `true` (+) and `false` (-).


`itersolve(clauses; vars::Integer=-1, verbose::Integer=0, proplimit::Integer=0)`
  - Returns an iterable object over all solutions.  When a user-defined propagation limit is specified, the iterator may not produce all feasible solutions.


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

### License
`PicoSAT.jl` and the original `picosat` C-library are licensed under the MIT "Expat" license.

### Contributors
  * Jake Bolewski - [@jakebolewski](http://github.com/jakebolewski)
  * Carlo Lucibello - [@CarloLucibello](https://github.com/CarloLucibello)
