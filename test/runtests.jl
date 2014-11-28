using PicoSAT
using Base.Test

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

# constructor tests
#@test_throws MethodError PicoSAT.solve(1)
@test_throws MethodError PicoSAT.solve([1, 1, Nothing])

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
gen_clauses1() = begin
end
