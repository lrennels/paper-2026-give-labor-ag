using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using Mimi, VegaLite, Random, Query, DataFrames, Dates

const pricelevel_2005_to_2020 = 113.648 / 87.504 # from Rennert et al. 2022 and (10/25/2021) BEA Table 1.1.9, line 1 GDP annual values as linked here: https://apps.bea.gov/iTable/iTable.cfm?reqid=19&step=3&isuri=1&select_all_years=0&nipa_table_list=13&series=a&first_year=2005&last_year=2020&scale=-99&categories=survey&thetable=
const seed = 24523438 # set any seed for reproducibility

# Load all functions
include(joinpath(@__DIR__, "..", "src", "main.jl"))

# Settings
num_trials = 10_000
discount_rates = [
                    (label = "1.5%", prtp = exp(9.149606e-05) - 1, eta = 1.016010e+00),
                    (label = "2.0%", prtp = exp(0.001972641) - 1, eta = 1.244458999),
                    (label = "2.5%", prtp = exp(0.004618784) - 1, eta = 1.421158088),
                    (label = "3.0%", prtp = exp(0.007702711) - 1, eta = 1.567899391)
                ] # Rennert et al. 2022
labor_functions = ["ISO", "Lancet"]

# Run analysis

@info "Starting epa 2023 analysis at $(now())"
include("00_epa2023.jl")

@info "Starting SCC analysis at $(now())"
include("01_compute_scc.jl")

@info "Starting ag SCC evolution analysis at $(now())"
include("02_ag_scc_evolution.jl")
