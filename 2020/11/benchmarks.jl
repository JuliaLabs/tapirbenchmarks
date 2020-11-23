using BenchmarkTools
const SUITE = BenchmarkGroup()

function skip_seq(s)
    s isa BenchmarkGroup || return s
    g = BenchmarkGroup()
    for (k, v) in pairs(s)
        k == (:impl => :seq) && continue
        g[k] = skip_seq(v)
    end
    return g
end

using TapirBenchmarks
for file in ["bench_divide_at_mean_with_map.jl", "bench_avgfilter1d_constprop.jl"]
    benchmarkdir = joinpath(pkgdir(TapirBenchmarks), "benchmark")
    suite0 = include(joinpath(benchmarkdir, file))
    if Threads.nthreads() == 1
        suite1 = suite0
    else
        suite1 = skip_seq(suite0)
    end
    SUITE[chop(file, head = length("bench_"), tail = length(".jl"))] = suite1
end
