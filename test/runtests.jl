using PicoSAT
using Test

# test clauses
# p cnf 5 3
# 1 -5 4 0
# -1 5 3 4 0
# -3 -4 0
nvars1, clauses1 = 5, Any[[1, -5, 4], [-1, 5, 3, 4], [-3, -4]]

# p cnf 2 2
# -1 0
# 1 0
nvars2, clauses2 = 2, Any[[-1], [1]]

# p cnf 2 3
# -1 2 0
# -1 -2 0
# 1 -2 0
nvars3, clauses3 = 2, Any[[-1, 2], [-1, -2], [1, -2]]

#### solve tests ####

# no clause
for n = 0:10
    res = PicoSAT.solve([], vars=n)
    @test res == [-i for i=1:n]
end

# c1 / c2 / c3 clauses
@test PicoSAT.solve(clauses1) == [1, -2, -3, -4, 5]
@test PicoSAT.solve(clauses2) === :unsatisfiable
@test PicoSAT.solve(clauses3, vars=3) == [-1, -2, -3]

# c1 proplimit
for lim = 1:20
    res = PicoSAT.solve(clauses1, proplimit=lim)
    if lim < 8
        @test res === :unknown
    else
        @test res == [1,-2,-3,-4,5]
    end
end
# c1 vars
@test PicoSAT.solve(clauses1, vars=7) == [1,-2,-3,-4,5,-6,-7]

# c1 iterables
@test PicoSAT.solve(tuple(clauses1...)) == [1, -2, -3, -4, 5]

function test_gen()
    Channel() do channel
        for c in clauses1
            put!(channel, c)
        end
    end
end

# test_gen() = begin
#     return (@task for c in clauses1
#         produce(c)
#     end)
# end
@test PicoSAT.solve(test_gen()) == [1,-2,-3,-4,5]

#### itersolve tests ####
function testsolution(clauses, sol)
    vars = Array{Int}(undef, length(sol))
    for i in sol
        vars[abs(i)] = i > 0
    end
    for clause in clauses
        nonetrue = true
        for i in clause
            if Bool(vars[abs(i)] ⊻ (i < 0))
                nonetrue = false
            end
        end
        nonetrue && return false
    end
    return true
end

# no clause
for n = 0:10
    @test length(collect(PicoSAT.itersolve([], vars=n))) == 2^n
end

# c1 iterables
@test all([testsolution(clauses1, sol)
    for sol in collect(PicoSAT.itersolve(clauses1))])

@test all([testsolution(clauses1, sol)
    for sol in collect(PicoSAT.itersolve(tuple(clauses1...)))])

@test all([testsolution(clauses1, sol)
    for sol in collect(PicoSAT.itersolve(test_gen()))])

# test c1
for sol in PicoSAT.itersolve(clauses1)
    @test testsolution(clauses1, sol)
end
let sols = collect(PicoSAT.itersolve(clauses1, vars=nvars1))
    @test length(sols) == 18
    @test length(Set([tuple(sol...) for sol in sols])) == 18
end

# repeats should give the same answer
let ref = Set([tuple(sol...) for sol in collect(PicoSAT.itersolve(clauses1))])
    cnf = Any[]
    for n = 1:50, c in clauses1
        push!(cnf, deepcopy(c))
    end
    @test Set([tuple(sol...) for sol in collect(PicoSAT.itersolve(cnf))]) == ref
end

# c1 / c2 / c3 clauses
@test collect(PicoSAT.itersolve(clauses1, proplimit=2)) == Any[]
@test collect(PicoSAT.itersolve(clauses2,vars=nvars2)) == Any[]
@test collect(PicoSAT.itersolve(clauses3, vars=3)) == Any[[-1, -2, -3], [-1, -2, 3]]

# Armin Biere, "Using High Performance SAT and QBF Solvers", presentation
# given 2011-01-24, pp. 23-48,
# http://fmv.jku.at/biere/talks/Biere-TPTPA11.pdf
# From "DIMACS example 1"
@test PicoSAT.solve(Any[[-2], [-1,-3], [1, 2], [2, 3]]) == :unsatisfiable

# From "Satisfying Assignments Example 2"
@test PicoSAT.solve(Any[[1,2], [-1,2], [-2,1]]) == [1,2]
@test PicoSAT.solve(Any[[1,2], [-1,2], [-2,1], [-1]]) == :unsatisfiable
@test PicoSAT.solve(Any[[1,2], [-1,2], [-2,1], [-2]]) == :unsatisfiable

@test PicoSAT.solve(Any[[ 1,  2,  3],
                        [ 1,  2, -3],
                        [ 1, -2,  3],
                        [ 1, -2, -3],
                        [ 4,  5,  6],
                        [ 4,  5, -6],
                        [ 4, -5,  6],
                        [ 4, -5, -6],
                        [-1, -4],
                        [ 1,  4]]) == :unsatisfiable

@test PicoSAT.solve(Any[[ 1,  2,  3],
                        [ 1,  2, -3],
                        [ 1, -2,  3],
                        [ 1, -2, -3],
                        [ 4,  5,  6],
                        [ 4,  5, -6],
                        [ 4, -5,  6],
                        [ 4, -5, -6],
                        [-1, -4],
                        [ 1,  4],
                        [-1, -3]]) == :unsatisfiable

# Test that we can run the examples
read, write = redirect_stdout()
include("../examples/pkg.jl")
