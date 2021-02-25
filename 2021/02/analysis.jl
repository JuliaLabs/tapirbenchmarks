using BenchmarkTools
using DataFrames
using Glob
using PkgBenchmark
using Plots

pgfplotsx()

resultdir = joinpath(@__DIR__, "build", "result")
results = map(PkgBenchmark.readresults, sort!(readdir(glob"result-*.json", resultdir)))

table_raw =
    Iterators.map(results) do r
        nthreads = parse(Int, r.benchmarkconfig.env["JULIA_NUM_THREADS"])
        Iterators.map(leaves(r.benchmarkgroup)) do ((bench, impl), trial)
            bench = Symbol(bench)
            impl = Symbol(impl)
            (; nthreads, bench, impl, trial)
        end
    end |>
    Iterators.flatten |>
    collect

df_raw = DataFrame(table_raw)
#-

begin
    df_tmp = select(df_raw, Not(:trial))
    df_tmp[!, :minimum] = map(trial -> minimum(trial).time, df_raw.trial)
    df_tmp[!, :median] = map(trial -> median(trial).time, df_raw.trial)
    df_tmp[!, :memory] = map(trial -> trial.memory, df_raw.trial)
    df_stats = stack(
        df_tmp,
        [:minimum, :median],
        variable_name = :time_stat,
        variable_eltype = Symbol,
        value_name = :time_ns,
    )
end
#-

df_summary = let
    idx = (df_stats.time_stat .== :minimum) .& (df_stats.nthreads .== 1)
    df1 = select(df_stats[idx, :], [:bench, :impl, :time_ns])
    df2 = combine(groupby(df1, :bench)) do g
        d = Dict(zip(g.impl, g.time_ns))
        (impl = g.impl, speedup = d[:seq] ./ g.time_ns)
    end
    noseq = df2.impl .!= :seq
    df3 = unstack(df2[noseq, :], :impl, :speedup)
    df3[!, :diff] = df3.tapir .- df3.current
    sort!(df3, order(:diff, rev = true))
    df3
end

plt1 = let
    xs = eachindex(df_summary.bench)
    plt = plot(
        ylabel = raw"Work efficiency ($T_S / T_1$)",
        xticks = (xs, ["\\mathtt{$x}" for x in df_summary.bench]),
        xtickfontsize = 11,
        xrotation = 80,
        xlims = (0.5, last(xs) + 0.5),
        ylims = (0, Inf),
        size = (200, 300),
        # foreground_color_legend = nothing,
    )
    scatter!(
        plt,
        xs,
        df_summary.tapir,
        markerstrokecolor = :blue,
        markersize = 6,
        markerstrokewidth = 3,
        markershape = :xcross,
        label = "Tapir",
    )
    scatter!(
        plt,
        xs,
        df_summary.current,
        color = :green,
        markersize = 6,
        markershape = :circle,
        label = "Current",
    )
    plot!(plt, [1], seriestype = "hline", color = :black, label = "")
    plt
end

savefig(
    plot(plt1, dpi = 300),
    joinpath(resultdir, "work_efficiency.png"),
)
