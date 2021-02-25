JULIA ?= julia
JULIA_CMD ?= $(JULIA) --startup-file=no
JULIA_PROJECT ?= $(PWD)
export JULIA_PROJECT

# Fix vanished x/y labels
GKSwstype ?= nul
export GKSwstype

.PHONY: all
all: benchmark

.PHONY: benchmark plot instantiate
benchmark plot instantiate: %: build/done.%

build/done.benchmark: build/done.instantiate
	$(JULIA_CMD) run_benchmarks.jl
	touch $@

build/done.instantiate: $(JULIA_PROJECT)/Manifest.toml
	JULIA_LOAD_PATH=@:@stdlib \
		JULIA_PKG_PRECOMPILE_AUTO=0 \
		$(JULIA_CMD) -e "using Pkg; Pkg.instantiate()"
	mkdir -p build
	touch $@

build/done.plot: build/done.benchmark
	$(JULIA_CMD) analysis.jl
	touch $@

.PHONY: replot
replot:
	$(JULIA_CMD) analysis.jl
	touch build/done.plot

.PHONY: clean
clean:
	rm -f build/done.*

Make.user: Make.user.tkf
	ln -s Make.user.tkf Make.user

-include Make.user
