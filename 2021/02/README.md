# A driver script for running benchmarks for Tapir

This directory contains a couple of scripts for running benchmarks for
the Tapir task API
[JuliaLang/julia#39773](https://github.com/JuliaLang/julia/pull/39773).

## Usage

### Step 1: Build JuliaLang/julia#39773

Clone `tkf/jltapir-pr` branch from `github.com/JuliaLang` and build
`julia`.

### Step 2: Create `Make.user`

Create `Make.user` with the path to `julia` binary built in step 1.

```make
JULIA = PATH/TO/julia
```

The default `Make.user` is `Make.user.tkf` that I (@tkf) use.

### Step 3: Run benchmarks

Following command runs the benchmarks and save the results in
`build/result/` directory:

```sh
make
```

### Step 4: Plot

Following command load the benchmark result and save the plots to
`build/result/*.png` files:

```sh
make plot
```
