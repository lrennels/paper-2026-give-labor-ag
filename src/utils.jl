using Interpolations, DataFrames, CSVFiles, Query

# TODO we should revisit this
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

    if agriculture_pctile == :mid
        pctile_value = 0.5
    elseif agriculture_pctile == :high
        pctile_value = 0.975
    elseif agriculture_pctile == :low
        pctile_value = 0.025
    else
        error("The agriculture_pctile argument must be one of :low (0.025), :mid (0.5) or :high (0.975)")
    end

    df = load(filepath) |>
            @filter(_.Scenario == "Crops Only" && _.Percentile == pctile_value) |>
            DataFrame

    select!(df, [:Country, :Degrees, :Valueadded_in_M_USD, :Initial_Income_in_M_USD])
    insertcols!(df, :impact_fraction => df.Valueadded_in_M_USD ./ df.Initial_Income_in_M_USD)
    select!(df, Not([:Valueadded_in_M_USD, :Initial_Income_in_M_USD]))

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

    select!(df, [:Country, :Degrees, :GCM, :Welfare_in_M_USD, :Initial_Income_in_M_USD])
    insertcols!(df, :impact_fraction => df.Welfare_in_M_USD ./ df.Initial_Income_in_M_USD)
    select!(df, Not([:Welfare_in_M_USD, :Initial_Income_in_M_USD]))

    rename!(df, [:Country => :gtap, :Degrees => :temp, :GCM => :gcm])

    return df
    
end