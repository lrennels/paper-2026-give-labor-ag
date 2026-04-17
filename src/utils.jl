using Interpolations, DataFrames, CSVFiles, Query

"""
    linear_interpolate(values::AbstractArray, original_domain::AbstractArray, new_domain::Union{AbstractArray, Number})
    
A helper function for linear interpolation of impact fractions between temperature
intervals. Original source: MimiMooreEtAlAgricultureImpacts package utils.jl
"""
function linear_interpolate(values::AbstractArray, original_domain::AbstractArray, new_domain::Union{AbstractArray, Number})
    # Build the interpolation object with linear interpolation between the provided points, and extrapolation beyond the points
    itp = extrapolate(interpolate((original_domain,), values, Gridded(Linear())), Line())    

    # Get the interpolated values for the point(s) in new_domain
    if new_domain isa Number 
        return itp(convert(Float64, new_domain)) # itp(x) returns a Ratios.SimpleRatio is x is just a single number, needs to be converted to a Float
    elseif new_domain isa Array
        return itp(new_domain)   # itp([x1, x2, etc]) returns an Array
    end
end

"""
    get_ag_gtap_df(filepath::String, agriculture_pctile::Symbol)

Process the GTAP output into ag_gtap_df for model input.
"""
function get_ag_gtap_df(filepath::String, agriculture_pctile::Symbol)
    
    if agriculture_pctile == :low
        pctile_value = 0.025
    elseif agriculture_pctile == :mid
        pctile_value = 0.5
    elseif agriculture_pctile == :high
        pctile_value = 0.975
    else
        error("The agriculture_pctile argument must be one of :low (0.025), :mid (0.5) or :high (0.975)")
    end

    df = load(filepath) |>
            @filter(_.Scenario == "Crops Only" && _.Percentile == pctile_value) |>
            DataFrame

    select!(df, [:Country, :Degrees, :Welfare_in_M_USD, :Valueadded_in_M_USD])
    insertcols!(df, :impact_fraction => df.Welfare_in_M_USD ./ df.Valueadded_in_M_USD)
    select!(df, Not([:Welfare_in_M_USD, :Valueadded_in_M_USD]))

    rename!(df, [:Country => :gtap, :Degrees => :temp])

    return df

end

"""
    get_labor_gtap_df(filepath::String)

Process the GTAP output into labor_gtap_df for model input.
"""
function get_labor_gtap_df(filepath::String)

    df = load(filepath) |>
            @filter(_.Scenario == "Labor Only (All Sectors)") |>
            DataFrame

    select!(df, [:Country, :Degrees, :GCM, :ST_AG_Welfare_in_M_USD, :ST_NONAG_Welfare_in_M_USD, :Initial_Income_in_M_USD])
    
    shares = load(joinpath(@__DIR__, "..", "data", "202505_SectorShare_v2.csv")) |> DataFrame
    rename!(shares, :agriculture => :agriculture_share)

    df = innerjoin(df, shares, on = [:Country => :gtap]) # join agriculture share data
    
    insertcols!(df, :ag_impact_fraction => df.ST_AG_Welfare_in_M_USD ./ (df.Initial_Income_in_M_USD .* df.agriculture_share))
    insertcols!(df, :nonag_impact_fraction => df.ST_NONAG_Welfare_in_M_USD ./ (df.Initial_Income_in_M_USD .* (1 .- df.agriculture_share)))
    
    select!(df, Not([:agriculture_share, :ST_AG_Welfare_in_M_USD, :ST_NONAG_Welfare_in_M_USD, :Initial_Income_in_M_USD]))
    rename!(df, [:Country => :gtap, :Degrees => :temp, :GCM => :gcm])

    return df
    
end

function get_probdists_gtap_df(filepath, n=1000)
    
    m = get_model() # admittedly this is overkill but being extremely careful to have the right iso3 order
    countries = dim_keys(m, :country) # get the country dimension keys from the model
    region_crosswalk = load(joinpath(@__DIR__, "..", "data", "region_crosswalk.csv")) |> DataFrame

    lowDF =  get_ag_gtap_df(filepath, :low)
    lowDF = unstack(lowDF, :gtap, :temp, :impact_fraction)
    lowDF = innerjoin(select(region_crosswalk, :iso3, :gtap), lowDF, on = :gtap)
    all(lowDF.iso3 .== countries) || error("The ag gtap dataframe iso3 column order does not match the country dimension keys.")
    select!(lowDF, Not(:gtap, :iso3)) # remove gtap column, as it is now redundant

    midDF =  get_ag_gtap_df(filepath, :mid)
    midDF = unstack(midDF, :gtap, :temp, :impact_fraction)
    midDF = innerjoin(select(region_crosswalk, :iso3, :gtap), midDF, on = :gtap)
    all(midDF.iso3 .== countries) || error("The ag gtap dataframe iso3 column order does not match the country dimension keys.")
    select!(midDF, Not(:gtap, :iso3)) # remove gtap column, as it is now redundant

    highDF = get_ag_gtap_df(filepath, :high)
    highDF = unstack(highDF, :gtap, :temp, :impact_fraction)
    highDF = innerjoin(select(region_crosswalk, :iso3, :gtap), highDF, on = :gtap)
    all(highDF.iso3 .== countries) || error("The ag gtap dataframe iso3 column order does not match the country dimension keys.")
    select!(highDF, Not(:gtap, :iso3)) # remove gtap column, as it is now redundant

    # For each region and temperature point we construct an interpolation where the x values are between 0 and 1
    # and the y values are the values from the three scenarios.
    dists = [LinearInterpolation([0.,0.5,1.], [lowDF[r,temp],midDF[r,temp], highDF[r,temp]]) for r in 1:184, temp in 1:7]

    # We only sample one set of random numbers, as we want perfect correlation between all the individual
    # parameter values.
    samples = rand(TriangularDist(0., 1., 0.5), n)

    # Now evaluate the interpolated function we created above with the samples from the triangular distributions
    sample_stores = [Mimi.SampleStore(dists[r,temp].(samples)) for r in 1:184, temp in 1:7]

    return countries, sample_stores

end