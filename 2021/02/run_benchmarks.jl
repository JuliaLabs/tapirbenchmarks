if isempty(ARGS)
    threads = 1:1
else
    threads = include_string(ARGS[1])
end

using PkgBenchmark

builddir = joinpath(@__DIR__, "build")
resultdir = joinpath(builddir, "result")
mkpath(resultdir)

for n in threads
    @info "Benchmarking JULIA_NUM_THREADS=$n"
    resultfile = joinpath(resultdir, "result-$n.json")
    group = benchmarkpkg(
        @__DIR__,
        BenchmarkConfig(
            env = Dict(
                "JULIA_PROJECT" => Base.active_project(),
                "JULIA_NUM_THREADS" => string(n),
            ),
        ),
        resultfile = resultfile,
        script = joinpath(@__DIR__, "benchmarks.jl"),
    )
    PkgBenchmark.export_markdown(joinpath(resultdir, "result-$n.md"), group)
end
