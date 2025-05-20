using Mimi, MimiGIVE, Query, CSVFiles, DataFrames

include("components/ag.jl")
include("components/labor.jl")

"""
    get_model(; agriculture_pctile::String = "mid",
                socioeconomics_source::Symbol = :RFF,
                SSP_scenario::Union{Nothing, String} = nothing,       
                RFFSPsample::Union{Nothing, Int} = nothing,
            )

Get a model with the given argument settings

- agriculture_pctile (default mid) - specify the `agriculture_pctile` input parameter
    as one of `["low", "mid", "high"]`, indicating which percentile to use. These
    map to low (2.5), mid (50.0) and high (97.5).

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
    https://github.com/rffscghg/MimiRFFSPs.jl.

"""
function get_model(;    agriculture_pctile::String = "mid",
                        socioeconomics_source::Symbol = :RFF,
                        SSP_scenario::Union{Nothing, String} = nothing,       
                        RFFSPsample::Union{Nothing, Int} = nothing,
                )
        
    # Settings 
    damages_first = 2020
    
    # Obtain original GIVE model
    m = MimiGIVE.get_model()

    # Remove Agriculture components and regional aggregators
    delete!(m, :Agriculture)
    delete!(m, :Agriculture_aggregator_pop90)
    delete!(m, :Agriculture_aggregator_gdp90)
    delete!(m, :Agriculture_aggregator_population)
    delete!(m, :Agriculture_aggregator_gdp)
    delete!(m, :AgricultureDamagesDisaggregator)
    delete!(m, :Damages_RegionAggregatorSum)
    delete!(m, :regional_netconsumption)

    # Set new dimensions
    dimension_gcm = load(joinpath(@__DIR__, "..", "data", "dimension_gcm.csv")) |> DataFrame
    set_dimension!(m, :gcm, dimension_gcm.GCM)

    # Add two new components
    add_comp!(m, Labor, :Labor, after = :CromarMortality, first = damages_first);
    add_comp!(m, Agriculture, :Agriculture, after = :Labor, first = damages_first);

    # --------------------------------------------------------------------------    
    # Labor
    # --------------------------------------------------------------------------

    labor_gtap_df = load()
    update_param!(m, :Labor, :gtap_df, labor_gtap_df)

    connect_param!(m, :Labor => :population, :Socioeconomic => :population)
    connect_param!(m, :Labor => :gdp, :Socioeconomic => :gdp)
    connect_param!(m, :Labor => :temp, :temperature => :T) # temperature from FaIR so relative to start year of 1750

    # --------------------------------------------------------------------------    
    # Agriculture
    # --------------------------------------------------------------------------

    ag_gtap_df = load()
    update_param!(m, :Agriculture, :gtap_df, ag_gtap_df)

    connect_param!(m, :Agriculture => :population, :Socioeconomic => :population)
    connect_param!(m, :Agriculture => :gdp, :Socioeconomic => :gdp)
    connect_param!(m, :Agriculture => :temp, :temperature => :T) # temperature from FaIR so relative to start year of 1750

end