using Mimi, MimiGIVE, Query, CSVFiles, DataFrames

"""
    get_model(; agriculture_pctile::Symbol = :mid,
                agrish_category::Symbol = :crops,
                socioeconomics_source::Symbol = :RFF,
                SSP_scenario::Union{Nothing, String} = nothing,       
                RFFSPsample::Union{Nothing, Int} = nothing,
            )

Get a model with the given argument settings

- agriculture_pctile (default :mid) - specify the `agriculture_pctile` input parameter
    as one of `[:low, :mid, :high]`, indicating which percentile to use. These
    map to low (2.5), mid (50.0) and high (97.5).

- agrish_category (default :crops) = specify the option for determining the source of 
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
    https://github.com/rffscghg/MimiRFFSPs.jl.

"""
function get_model(;    agriculture_pctile::Symbol = :mid,
                        agrish_category::Symbol = :crops,
                        socioeconomics_source::Symbol = :RFF,
                        SSP_scenario::Union{Nothing, String} = nothing,       
                        RFFSPsample::Union{Nothing, Int} = nothing,
                )

    # Settings 
    damages_first = 2020
    
    # Keys
    region_crosswalk = load(joinpath(@__DIR__, "..", "data", "region_crosswalk.csv")) |> DataFrame

    # Obtain original GIVE model
    m = MimiGIVE.get_model(;
                            socioeconomics_source = socioeconomics_source,
                            SSP_scenario = SSP_scenario,
                            RFFSPsample = RFFSPsample
                        )

    # Remove Agriculture components and regional aggregators
    delete!(m, :Agriculture)
    delete!(m, :Agriculture_aggregator_pop90)
    delete!(m, :Agriculture_aggregator_gdp90)
    delete!(m, :Agriculture_aggregator_population)
    delete!(m, :Agriculture_aggregator_gdp)
    delete!(m, :AgricultureDamagesDisaggregator)
    delete!(m, :Damages_RegionAggregatorSum)
    delete!(m, :regional_netconsumption)
    delete!(m, :RegionalPerCapitaGDP)

    # Replace GIVE Damage Aggrgator with new one including labor and removing
    # some unneeded intermediates
    replace!(m, :DamageAggregator => DamageAggregator)
    
    # Need to set this damage aggregator to run from 2020 to 2300, currently picks up
    # 1750 to 2300 from replace!
    Mimi.set_first_last!(m, :DamageAggregator, first=2020);

    # Set new dimensions
    dimension_gcm = load(joinpath(@__DIR__, "..", "data", "dimension_gcm.csv")) |> DataFrame
    dimension_gcm.GCM[1] == "model_ensemble" || error("The first element of the GCM dimension should be 'modeL_ensemble', currently it is $(dimension_gcm.GCM[1]).")
    set_dimension!(m, :gcm, dimension_gcm.GCM)

    # Add two new components
    add_comp!(m, Labor, :Labor, after = :CromarMortality, first = damages_first);
    add_comp!(m, Agriculture, :Agriculture, after = :Labor, first = damages_first);

    # --------------------------------------------------------------------------    
    # Labor
    # --------------------------------------------------------------------------

    # GTAP impact fractions
    labor_gtap_df = DataFrame()
    for iso3 in dim_keys(m, :country), gcm in dim_keys(m, :gcm), temp in collect(1.:0.5:4.)
        append!(labor_gtap_df, DataFrame(:iso3 => iso3, :gcm => gcm, :temp => temp))
    end
    labor_gtap_df = innerjoin(labor_gtap_df, select(region_crosswalk, [:iso3, :gtap]), on = :iso3) # join gtap labels

    filepath = joinpath(@__DIR__, "..", "data", "gtap_output", "202505_Plants_People_v2.csv")
    impact = get_labor_gtap_df(filepath)

    labor_gtap_df = innerjoin(labor_gtap_df, impact, on = [:gtap, :gcm, :temp]) # join agriculture share data
    select!(labor_gtap_df, Not(:gtap))

    labor_gtap = Array{Float64}(undef, length(dim_keys(m, :country)), 7, length(dim_keys(m, :gcm)))
    for (i, gcm) in enumerate(dim_keys(m, :gcm))
        df = labor_gtap_df |> @filter(_.gcm == gcm) |> DataFrame
        select!(df, Not(:gcm))
        df = unstack(df, :temp, :impact_fraction)

        # some checks on dimensions
        all(df.iso3 .== dim_keys(m, :country)) || error("The labor gtap dataframe iso3 row order does not match the country dimension keys.")
        all(names(df)[2:end] .== string.(collect(1.:0.5:4.))) || error("The labor gtap dataframe column order does not match the temperature keys.")

        labor_gtap[:, :, i] = df[!, 2:end] |> Matrix
    end
    update_param!(m, :Labor, :gtap_impacts, labor_gtap)

    # Connections
    connect_param!(m, :Labor => :population, :Socioeconomic => :population)
    connect_param!(m, :Labor => :gdp, :Socioeconomic => :gdp)
    connect_param!(m, :Labor => :temp, :temperature => :T) # temperature from FaIR so relative to start year of 1750

    # --------------------------------------------------------------------------    
    # Agriculture
    # --------------------------------------------------------------------------

    # Agriculture share
    agrish0_df = DataFrame(:iso3 => dim_keys(m, :country)) # start with the country list
    agrish0_df = innerjoin(agrish0_df, select(region_crosswalk, [:iso3, :gtap]), on = :iso3) # join gtap labels

    shares = load(joinpath(@__DIR__, "..", "data", "202505_SectorShare_v2.csv")) |> DataFrame
    agrish0_df = innerjoin(agrish0_df, shares, on = :gtap) # join agriculture share data

    update_param!(m, :Agriculture, :agrish0, agrish0_df[!, agrish_category])

    # Population and GDP in 2017 for agrish basis
    # TODO
    # update_param!(m, :Agriculture, :gdp2017, gdp2017)
    # update_param!(m, :Agriculture, :population2017, population2017)

    # GTAP impact fractions
    ag_gtap_df = DataFrame()
    for iso3 in dim_keys(m, :country), temp in collect(1.:0.5:4.)
        append!(ag_gtap_df, DataFrame(:iso3 => iso3, :temp => temp))
    end
    ag_gtap_df = innerjoin(ag_gtap_df, select(region_crosswalk, [:iso3, :gtap]), on = :iso3) # join gtap labels

    filepath = joinpath(@__DIR__, "..", "data", "gtap_output", "202505_Plants_People_v2.csv")
    impact = get_ag_gtap_df(filepath, agriculture_pctile)
    ag_gtap_df = innerjoin(ag_gtap_df, impact, on = [:gtap, :temp]) # join agriculture share data

    select!(ag_gtap_df, Not(:gtap))
    ag_gtap_df = unstack(ag_gtap_df, :temp, :impact_fraction)

    # some checks on dimensions
    all(ag_gtap_df.iso3 .== dim_keys(m, :country)) || error("The ag gtap dataframe iso3 row order does not match the country dimension keys.")
    all(names(ag_gtap_df)[2:end] .== string.(collect(1.:0.5:4.))) || error("The ag gtap dataframe column order does not match the temperature keys.")

    ag_gtap = ag_gtap_df[!, 2:end] |> Matrix
    update_param!(m, :Agriculture, :gtap_impacts, ag_gtap)

    # Connections
    connect_param!(m, :Agriculture => :population, :Socioeconomic => :population)
    connect_param!(m, :Agriculture => :gdp, :Socioeconomic => :gdp)
    connect_param!(m, :Agriculture => :temp, :temperature => :T) # temperature from FaIR so relative to start year of 1750

    # --------------------------------------------------------------------------    
    # Damage Aggregator
    # --------------------------------------------------------------------------

    connect_param!(m, :DamageAggregator => :damage_ag, :Agriculture => :agcost)
    connect_param!(m, :DamageAggregator => :damage_labor, :Labor => :laborcost)

    return m
end
