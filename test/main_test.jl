using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using Mimi, VegaLite, Random, Query, DataFrames, Dates

@info "Starting agriculture testing at $(now())"
include("test_ag.jl")
include("test_ag_scc.jl")

@info "Starting labor testing at $(now())"
include("test_labor.jl")

@info "Starting mcs testing at $(now())"
include("test_mcs.jl")

@info "Starting scc testing at $(now())"
include("test_scc.jl")
