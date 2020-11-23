using BenchmarkTools
using DataFrames
using Glob
using PkgBenchmark
using Plots

resultdir = joinpath(@__DIR__, "build", "result")
raw_results = map(PkgBenchmark.readresults, sort!(readdir(glob"result-*.json", resultdir)))

module _IncludeWorkspace end

results = map(raw_results) do r
    dict = Dict()
    for (k0, g) in r.benchmarkgroup
        dict[k0] = map(leaves(g)) do (k1, b)
            nt = (; map(s -> include_string(_IncludeWorkspace, s), k1)...)
            return (nt, b)
        end
    end
    return (dict = dict, raw = r)
end

function benchmarks_as_table(results, benchname)
    Iterators.map(results) do r
        nthreads = parse(Int, r.raw.benchmarkconfig.env["JULIA_NUM_THREADS"])
        Iterators.map(r.dict[benchname]) do (nt, b)
            (; nthreads, time = minimum(b.times), nt...)
        end
    end |>
    Iterators.flatten |>
    collect
end

df_divide_at_mean_with_map =
    DataFrame(benchmarks_as_table(results, "divide_at_mean_with_map"))
df_avgfilter1d_constprop = DataFrame(benchmarks_as_table(results, "avgfilter1d_constprop"))
let df = df_avgfilter1d_constprop
    df[df.impl.==:tapir_dac, :impl] .= Ref(:tapir)
    df
end

sort!(df_divide_at_mean_with_map, [:impl, :f, :nthreads])
sort!(df_avgfilter1d_constprop, [:impl, :n, :nthreads])

function seq_dict(df)
    df = df[df.impl.==:seq, :]
    ks = setdiff(propertynames(df), [:time, :impl, :nthreads])
    Iterators.map(pairs(groupby(df, ks))) do (k, v)
        ps = pairs(k)
        (; ps...) => only(v.time)
    end |> Dict
end

noimpl(k) = (; ((kk => kv for (kk, kv) in pairs(k) if kk !== :impl))...)

seq_divide_at_mean_with_map = seq_dict(df_divide_at_mean_with_map)
seq_avgfilter1d_constprop = seq_dict(df_avgfilter1d_constprop)

plt_speedup_divide_at_mean_with_map = let df = df_divide_at_mean_with_map
    seq_data = seq_divide_at_mean_with_map

    plt = plot(
        xlabel = "Number of threads",
        ylabel = "Speedup",
        # legend = :topleft,
        legend = :outertopright,
        foreground_color_legend = nothing, # no border
        size = (400, 200),
    )
    for (k, df) in pairs(groupby(df[df.impl.!=:seq, :], [:f, :impl]))
        nt = noimpl(k)
        speedup = seq_data[nt] ./ df.time
        plot!(
            plt,
            df.nthreads,
            speedup,
            label = "$(k.impl) (f=$(k.f))",
            linestyle = k.impl == :threads ? :dash : :solid,
            markershape = :x,
        )
    end
    plot!(plt, [1], linetype = :hline, color = :black, label = "")

    plt
end
savefig(
    plot(plt_speedup_divide_at_mean_with_map, dpi = 300),
    joinpath(resultdir, "speedup_divide_at_mean_with_map.png"),
)

plt_time_divide_at_mean_with_map = let df = df_divide_at_mean_with_map
    seq_data = seq_divide_at_mean_with_map

    plt_threads = plot(
        xlabel = "Number of threads",
        ylabel = "Time ratio w.r.t sequential algorithm",
        legend = (0.5, 0.5),
    )
    for (k, df) in pairs(groupby(df[df.impl.!=:seq, :], [:f, :impl]))
        nt = noimpl(k)
        time = df.time ./ seq_data[nt]
        plot!(plt_threads, df.nthreads, time, label = "$(k.impl) (f=$(k.f))")
    end
    plot!(plt_threads, [1], linetype = :hline, color = :black, label = "")

    plt_tapir = plot(
        xlabel = "Number of threads",
        ylabel = "Time ratio w.r.t seq. (Zoom)",
        legend = :none,
    )
    for (k, df) in pairs(groupby(df[df.impl.==:tapir, :], :f))
        nt = noimpl(k)
        time = df.time ./ seq_data[nt]
        plot!(plt_tapir, df.nthreads, time, label = "(f=$(k.f))")
    end
    plot!(plt_tapir, [1], linetype = :hline, color = :black, label = "")

    plot(plt_threads, plt_tapir)
end
savefig(
    plot(plt_time_divide_at_mean_with_map, dpi = 300),
    joinpath(resultdir, "time_divide_at_mean_with_map.png"),
)

plt_speedup_avgfilter1d_constprop = let df = df_avgfilter1d_constprop
    seq_data = seq_avgfilter1d_constprop

    vary_n = true
    # vary_n = false
    if !vary_n
        df = df[df.n.==2^25, :]
    end

    plt = plot(
        xlabel = "Number of threads",
        ylabel = "Speedup",
        # legend = :topleft,
        legend = (0.5, 0.5),
        foreground_color_legend = nothing, # no border
        size = (300, 200),
    )
    for (k, df) in pairs(groupby(df[df.impl.!=:seq, :], [:n, :impl]))
        nt = noimpl(k)
        speedup = seq_data[nt] ./ df.time
        e = Int(log2(k.n))
        plot!(
            plt,
            df.nthreads,
            speedup,
            label = vary_n ? "$(k.impl) (n=2^$e)" : "$(k.impl)",
            linestyle = k.impl == :threads ? :dash : :solid,
            markershape = :x,
        )
    end
    plot!(plt, [1], linetype = :hline, color = :black, label = "")

    plt
end
savefig(
    plot(plt_speedup_avgfilter1d_constprop, dpi = 300),
    joinpath(resultdir, "speedup_avgfilter1d_constprop.png"),
)

plt_time_avgfilter1d_constprop = let df = df_avgfilter1d_constprop
    seq_data = seq_avgfilter1d_constprop

    vary_n = true
    # vary_n = false
    if !vary_n
        df = df[df.n.==2^25, :]
    end

    plt_threads = plot(
        xlabel = "Number of threads",
        ylabel = "Time ratio w.r.t sequential algorithm",
        # legend = (0.5, 0.5),
    )
    for (k, df) in pairs(groupby(df[df.impl.!=:seq, :], [:n, :impl]))
        nt = noimpl(k)
        time = df.time ./ seq_data[nt]
        e = Int(log2(k.n))
        plot!(
            plt_threads,
            df.nthreads,
            time,
            label = vary_n ? "$(k.impl) (n=2^$e)" : "$(k.impl)",
            linestyle = k.impl == :threads ? :dash : :solid,
        )
    end
    plot!(plt_threads, [1], linetype = :hline, color = :black, label = "")

    plt_tapir = plot(
        xlabel = "Number of threads",
        ylabel = "Time ratio w.r.t seq. (Zoom)",
        legend = :none,
    )
    for (k, df) in pairs(groupby(df[df.impl.==:tapir, :], :n))
        nt = noimpl(k)
        time = df.time ./ seq_data[nt]
        e = Int(log2(k.n))
        plot!(plt_tapir, df.nthreads, time, label = vary_n ? "(n=2^$e)" : "")
    end
    plot!(plt_tapir, [1], linetype = :hline, color = :black, label = "")

    plot(plt_threads, plt_tapir)
end
savefig(
    plot(plt_time_avgfilter1d_constprop, dpi = 300),
    joinpath(resultdir, "time_avgfilter1d_constprop.png"),
)
