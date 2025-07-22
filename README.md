# Labor and Agriculture Damages -- a Modified GIVE Model

This repository holds scripts and analysis to modify the Greenhouse Gas Impact Valuation Estimator (GIVE) model (Rennert et al. 2022) with (1) and updated agriculture sector damage function and (2) a labor sector damage function.

# 1. Preparing the Software Environment

You need to install [Julia](https://julialang.org/) to run this model. You also may want to use the official IDE for Julia, [Visual Studio Code](https://code.visualstudio.com).

Once you download Julia, navigating to the top `src` folder and running the `main.jl` script will include all functions and structures you need to run the model. 

```julia
include("main.jl")
```
# 2. Analysis

The analysis folder holds all scripts used for the paper. In addition, the `examples.ipynb` notebook gives examples of the main available functionality.

# 3. Run Model Function

The primary workhorse function is `run_model`, which returns the runnable Mimi model and is defined as:

```julia
function get_model(;    agriculture_pctile::Symbol = :mid,
                        agrish_category::Symbol = :agriculture,
                        socioeconomics_source::Symbol = :RFF,
                        SSP_scenario::Union{Nothing, String} = nothing,       
                        RFFSPsample::Union{Nothing, Int} = 6546,
                )
```

The key arguments for this function are as follows:

- agriculture_pctile (default :mid) - specify the `agriculture_pctile` input parameter
    as one of `[:low, :mid, :high]`, indicating which percentile to use. These
    map to low (2.5), mid (50.0) and high (97.5).

- agrish_category (default :agriculture) = specify the option for determining the source of 
    agriculture share as one of :crops and :agriculture 

- socioeconomics_source (default :RFF) - The options are :RFF, which uses data from 
    the RFF socioeconomic projections, or :SSP, which uses data from one of the 
    Shared Socioeconomic Pathways

- SSP_scenario (default to nothing) - This setting is used only if one is using 
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

- RFFSPsample (default to nothing, which will pull the in MimiRFFSPs) - choose
    the sample for which to run the RFF SP. See the RFFSPs component here: 
    https://github.com/rffscghg/MimiRFFSPs.jl. This will default to the same 
    default run (6546) as the RFFSPs component, and is used for the default ypc2017
    parameter in the agriculture component.

# 4. Monte Carlo Simulations

# 5. Social Cost of Carbon
