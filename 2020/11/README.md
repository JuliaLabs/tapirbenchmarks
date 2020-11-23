# A driver script for running TapirBenchmarks.jl

This directory contains a couple of scripts for running a selected
benchmarks from TapirBenchmarks.jl.

## Usage

### Step 1: Build cesmix-mit/julia

Clone https://github.com/cesmix-mit/julia and build `julia` with
`USE_TAPIR=1` option.

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
