# paper-2026-give-labor-ag

This repository holds scripts and analysis to modify the Greenhouse Gas Impact Valuation Estimator (GIVE) model (Rennert et al., 2022) with (1) an updated agriculture sector damage function and (2) a labor sector damage function for publication in Moore et al. (2026).

# Requirements

1. Julia is free and available for download [here](https://julialang.org/). Estimation was performed on Julia 1.12.5. While newer versions of Julia are compatible with all the code, the random number generators were updated and results might not be identical due to differences in the random parameters underlying the Monte Carlo runs. Install Julia and ensure that it can be invoked (run) from where the replication repository is to be cloned ("in your path").

2. Optional: Visual Studio Code (VScode) [here](https://code.visualstudio.com) is an excellent IDE for use with Julia.

3. Optional: Github is free and available for download [here](https://github.com/git-guides/install-git). Github is used to house this repository and by installing and using it to clone the repository one will simplify the replication procedure. However, a user could also simply download a zipped file version of this repository, unzip in the desired location, and follow the replication procedures outlined below.

# 1. Getting Started

Begin by cloning or downloading a copy of this repository. This can be done by clicking on the green "code" button in this repository and following those instructions, or by navigating in the terminal via the command line to the desired location of the cloned repository and then typing:
```
git clone https://github.com/lrennels/paper-2026-give-labor-ag
```
Alternatively, you can make a fork of this repository and work from the fork in the same way. This allows for development on the fork while preserving its relationship with this repository.

# Code and Model Structure

## Run Main Analysis
The `analysis` folder holds all scripts used for the paper. From within the `analysis` folder, users may start a Julia REPL with `julia` and then call

```julia
include("main.jl") 
``` 
or, equivalently, from the repository root run the following in the terminal
```
julia analysis/main.jl
```
The first script in `main.jl` activates and instantiates the project environment (`Project.toml`/`Manifest.toml`), so the exact package versions used for the paper are installed automatically on the first run.

Running `main.jl` calls the three primary analysis scripts
1. `01_epa2023.jl`
2. `02_compute_scc.jl`
3. `03_ag_scc_evolution.jl`.

## The Core `get_model` Function

The workhorse function in this repository is `get_model`, which returns the runnable Mimi model, built off of the default `MimiGIVE` model, and is defined as:

```julia
function get_model(;    agriculture_pctile::Symbol = :mid,
                        socioeconomics_source::Symbol = :RFF,
                        SSP_scenario::Union{Nothing, String} = nothing,       
                        RFFSPsample::Union{Nothing, Int} = 6546,
                        labor_damage_function::String = "Lancet"
                )
```

The key arguments for this function are as follows:

- `agriculture_pctile` (default :mid) - specify the `agriculture_pctile` input parameter
    as one of `[:low, :mid, :high]`, indicating which percentile to use. These
    map to low (2.5), mid (50.0) and high (97.5).

- `socioeconomics_source` (default :RFF) - The options are :RFF, which uses data from 
    the RFF socioeconomic projections, or :SSP, which uses data from one of the 
    Shared Socioeconomic Pathways

- `SSP_scenario` (default to nothing) - This setting is used only if one is using 
    the SSPs as the socioeconomics_source, and the current options are "SSP119", 
    "SSP126", "SSP245", "SSP370", "SSP585", and this will be used as follows.
    See the SSPs component here: https://github.com/anthofflab/MimiSSPs.jl for more information.

    (1) Select the population and GDP trajectories for 2020 through 2300, mapping
        each RCMIP scenario to the SSP (SSP1, 2, 3, 5 respectively)
    
    (2) Choose the ar6 scenario for data from 1750 - 2019 and the RCMIP emissions 
        scenario from the MimiSSPs component to pull Leach et al. RCMIP scenario
        data for 2020 to 2300 for CO2, CH4, and N2O.

    (NOTE) that if the socioeconomics_source is :RFF this will not be consequential 
        and ssp245 will be used for the ar6 data from 1750 - 2019 and trace gases 
        from 2020 onwards, while emissions for CO2, CH4, and N2O will come from
        the MimiRFFSPs component.

- `RFFSPsample` (default 6546) - choose
    the sample for which to run the RFF SP. See the RFFSPs component here: 
    https://github.com/rffscghg/MimiRFFSPs.jl. This will default to the same 
    default run (6546) as the RFFSPs component, and is used for the default ypc2017
    parameter in the agriculture component.

- `labor_damage_function` (default "Lancet") - specify the damage function to use
    for labor damages, the options are "Lancet" or "ISO"

## Monte Carlo Simulations

The `run_mcs` function is the workhorse function for running a Monte Carlo Simulation for this model. It runs a Monte Carlo Simulation mirroring that of the original `MimiGIVE` model, with two additions:

1. For the agriculture component add uncertainty across each of the seven coefficients.

```julia
filepath = joinpath(@__DIR__, "..", "data", "gtap_output/202505_Plants_People_Agriculture.csv")
countries, ag_sample_stores = get_probdists_gtap_df(filepath, trials)

for coef in [1,2,3,4,5,6,7] # seven coefficients defined with an anonymous dimension
    for (i, country) in enumerate(countries)
        rv_name = Symbol("rv_gtap_coef$(coef)_$country")
        Mimi.add_RV!(mcs, rv_name, ag_sample_stores[i, coef])
        Mimi.add_transform!(mcs, :Agriculture, :gtap_impacts, :(=), rv_name, [country, coef])
    end
end
```

2. For the labor component add a Uniform distribution across all possible GCMs, excluding the model ensemble which runs the default, non-MCS mode.

```julia
gcm_options = collect(2:size(load(joinpath(@__DIR__, "..", "data", "dimension_gcm.csv")) |> DataFrame, 1)) # 1 is the ensemble
rv_name = :labor_gcm
Mimi.add_RV!(mcs, rv_name, Mimi.EmpiricalDistribution(gcm_options)) # add random variable 
Mimi.add_transform!(mcs, :Labor, :gcm, :(=), rv_name) # connect random variable to parameter
```

The `run_mcs` function is defined as:

```julia
function run_mcs(;  trials::Int64 = 10000, 
                    output_dir::Union{String, Nothing} = nothing, 
                    save_trials::Bool = false,
                    fair_parameter_set::Symbol = :random,
                    fair_parameter_set_ids::Union{Vector{Int}, Nothing} = nothing,
                    rffsp_sampling::Symbol = :random,
                    rffsp_sampling_ids::Union{Vector{Int}, Nothing} = nothing,
                    m::Mimi.Model = get_model(), # <-- using the default model from this repository, which is a modified/augmented version of GIVE
                    save_list::Vector = [],
                    results_in_memory::Bool = true,
                )
```
The key arguments for this function are as follows:

- `trials` (default 10,000) - number of trials to be run, used for presampling
- `output_dir` (default constructed folder name) - folder to hold results 
- `save_trials` (default false) - whether to save all random variables for all trials to trials.csv 
- `fair_parameter_set` (default :random) - :random means FAIR mcs samples will be 
        chosen randomly from the provided sets, while :deterministic means they will 
        be  based on the provided vector of to `fair_parameter_set_ids` keyword argument. 
- `fair_parameter_set_ids` - (default nothing) - if `fair_parameter_set` is set 
        to :deterministic, this `n` element vector provides the fair parameter set ids 
        that will be run, otherwise it is set to `nothing` and ignored.
- `rffsp_sampling` (default :random) - which sampling strategy to use for the RFF 
        SPs, :random means RFF SPs will be chosen randomly, while :deterministic means they 
        will be based on the provided vector of to `rffsp_sampling_ids` keyword argument. 
- `rffsp_sampling_ids` - (default nothing) - if `rffsp_sampling` is set to :deterministic, 
        this `n` element vector provides the RFF SP ids that will be run, otherwise it is 
        set to `nothing` and ignored.
- `m` (default get_model()) - the model to run the simulation for
- `save_list` (default []) - which parameters and variables to save for each trial,
        entered as a vector of Tuples (:component_name, :variable_name)
- `results_in_memory` (default true) - this should be turned off if you are running 
        into memory problems, data will be streamed out to disk but not saved in memory 
        to the mcs object

## Social Cost of Carbon

The `compute_scc` function computes the social cost of carbon and mirrors that in the `MimiGIVE` model nearly identically. 

```julia
function compute_scc(m::Model = get_model(); 
            year::Union{Int, Nothing} = nothing, 
            last_year::Int = _model_years[end], 
            prtp::Union{Float64,Nothing} = 0.015, 
            eta::Union{Float64,Nothing} = 1.45,
            discount_rates = nothing,
            certainty_equivalent = false,
            fair_parameter_set::Symbol = :random,
            fair_parameter_set_ids::Union{Vector{Int}, Nothing} = nothing,
            rffsp_sampling::Symbol = :random,
            rffsp_sampling_ids::Union{Vector{Int}, Nothing} = nothing,
            n = 0,
            gas::Symbol = :CO2,
            save_list::Vector = [],
            output_dir::Union{String, Nothing} = nothing,
            save_md::Bool = false,
            save_cpc::Bool = false,
            compute_sectoral_values::Bool = false,
            CIAM_foresight::Symbol = :perfect,
            CIAM_GDPcap::Bool = false,
            post_mcs_creation_function = nothing,
            pulse_size::Float64 = 1.,
            compute_labor_country_sccs::Bool = false
        )
```

We make one addition to the original function with the `compute_labor_country_sccs` Boolean flag. If this is set to `true` we return an additional entry in the `results` dictionary which saves the country-level partial social costs of carbon for the labor sector, including the expected value, individual SCCs, and standard errors.

For examples of how to run the SCC computations and parse the outputs see `analysis/02_compute_scc.jl`.
