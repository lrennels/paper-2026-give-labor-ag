using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using Mimi, VegaLite, Random, Query, DataFrames, Dates

const pricelevel_2005_to_2020 = 113.648 / 87.504
const seed = 24523438

# Load all functions
include(joinpath(@__DIR__, "..", "src", "main.jl"))

# Settings
year = 2020
num_trials = 10_000
discount_rates = [
    (label = "1.5%", prtp = exp(9.149606e-05) - 1, eta = 1.016010e+00),
    (label = "2.0%", prtp = exp(0.001972641) - 1, eta = 1.244458999),
    (label = "2.5%", prtp = exp(0.004618784) - 1, eta = 1.421158088),
    (label = "3.0%", prtp = exp(0.007702711) - 1, eta = 1.567899391)
]

# Run analysis
@info "Starting SCC analysis at $(now())"
include("01_compute_scc.jl")

@info "Starting ag SCC evolution analysis at $(now())"
include("02_ag_scc_evolution.jl")
