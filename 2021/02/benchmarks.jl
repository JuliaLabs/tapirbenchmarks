using Base.Experimental: Tapir
using TapirBenchmarks

@inline function avgfilter!(ys, xs, N)
    @assert axes(ys) == axes(xs)
    for offset in firstindex(xs)-1:lastindex(xs)-N
        y = zero(eltype(xs))
        for k in 1:N
            y += @inbounds xs[offset+k]
        end
        @inbounds ys[offset+1] = y / N
    end
    return ys
end

function demo_avgfilter!(ys1, ys2, xs1, xs2)
    N = 32
    Tapir.@sync begin
        Tapir.@spawn avgfilter!(ys1, xs1, N)
        avgfilter!(ys2, xs2, N)
    end
    return ys1, ys2
end

function demo_avgfilter_current!(ys1, ys2, xs1, xs2)
    N = 32
    @sync begin
        Threads.@spawn avgfilter!(ys1, xs1, N)
        avgfilter!(ys2, xs2, N)
    end
    return ys1, ys2
end

function demo_avgfilter_seq!(ys1, ys2, xs1, xs2)
    N = 32
    avgfilter!(ys1, xs1, N)
    avgfilter!(ys2, xs2, N)
    return ys1, ys2
end

@inline function eliminatable_computation(xs)
    a = typemax(UInt)
    b = 0
    for x in xs
        a = (typemax(a) + a) ÷ ifelse(x == 0, 1, x)
        b += x
    end
    return (a, b)
end

function demo_dce()
    local b1, b2
    Tapir.@sync begin
        Tapir.@spawn begin
            a1, b1 = eliminatable_computation(UInt(1):UInt(262144))
        end
        a2, b2 = eliminatable_computation(UInt(3):UInt(262144))
    end
    return b1 + b2   # a1 and a2 not used
end

function demo_dce_current()
    local b1, b2
    @sync begin
        Threads.@spawn begin
            a1, b1 = eliminatable_computation(UInt(1):UInt(262144))
        end
        a2, b2 = eliminatable_computation(UInt(3):UInt(262144))
    end
    return b1 + b2
end

function demo_dce_seq()
    a1, b1 = eliminatable_computation(UInt(1):UInt(262144))
    a2, b2 = eliminatable_computation(UInt(3):UInt(262144))
    return b1 + b2
end

mutable struct AB
    a::Int
    b::Int
end

@noinline need_nonnegative(x) = error("require nonnegative number; got $x")

@inline function sumto!(r, p, xs)
    for x in xs
        x < 0 && need_nonnegative(x)
        setproperty!(r, p, getproperty(r, p) + x)
    end
end

@noinline function demo_sroa()
    ab = AB(0, 0)
    Tapir.@sync begin
        Tapir.@spawn sumto!(ab, :a, 1:2:2^20)
        sumto!(ab, :b, 2:2:2^20)
    end
    return ab.a + ab.b
end

@noinline function demo_sroa_current()
    ab = AB(0, 0)
    @sync begin
        Threads.@spawn sumto!(ab, :a, 1:2:2^20)
        sumto!(ab, :b, 2:2:2^20)
    end
    return ab.a + ab.b
end

@noinline function demo_sroa_seq()
    ab = AB(0, 0)
    sumto!(ab, :a, 1:2:2^20)
    sumto!(ab, :b, 2:2:2^20)
    return ab.a + ab.b
end

using BenchmarkTools
SUITE = BenchmarkGroup()

let s = SUITE["constprop"] = BenchmarkGroup()
    xs1 = randn(2^16)
    ys1 = zero(xs1)
    xs2 = randn(length(xs1))
    ys2 = zero(xs2)

    @assert demo_avgfilter!(zero(ys1), zero(ys2), xs1, xs2) ==
            demo_avgfilter_current!(ys1, ys2, xs1, xs2)
    @assert demo_avgfilter!(zero(ys1), zero(ys2), xs1, xs2) ==
            demo_avgfilter_seq!(ys1, ys2, xs1, xs2)

    s["tapir"] = @benchmarkable demo_avgfilter!($ys1, $ys2, $xs1, $xs2)
    s["current"] = @benchmarkable demo_avgfilter_current!($ys1, $ys2, $xs1, $xs2)
    s["seq"] = @benchmarkable demo_avgfilter_seq!($ys1, $ys2, $xs1, $xs2)
end

let s = SUITE["dce"] = BenchmarkGroup()
    @assert demo_dce() == demo_dce_current()
    @assert demo_dce() == demo_dce_seq()
    s["tapir"] = @benchmarkable demo_dce()
    s["current"] = @benchmarkable demo_dce_current()
    s["seq"] = @benchmarkable demo_dce_seq()
end

let s = SUITE["sroa"] = BenchmarkGroup()
    @assert demo_sroa() == demo_sroa_current()
    @assert demo_sroa() == demo_sroa_seq()
    s["tapir"] = @benchmarkable demo_sroa()
    s["current"] = @benchmarkable demo_sroa_current()
    s["seq"] = @benchmarkable demo_sroa_seq()
end

let s = SUITE["inference"] = BenchmarkGroup()
    xs = rand(2^15)
    s["tapir"] = @benchmarkable divide_at_mean_tapir($xs)
    s["current"] = @benchmarkable divide_at_mean_threads($xs)
    s["seq"] = @benchmarkable divide_at_mean_seq($xs)
end
