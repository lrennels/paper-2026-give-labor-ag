using Mimi, VegaLite, StatsBase, Dates

output_dir = joinpath(@__DIR__, "output", "labor")
mkpath(output_dir)

# Load all functions
include(joinpath(@__DIR__, "..", "src", "main.jl"))

# Options
gcms = (load(joinpath(@__DIR__, "..", "data", "dimension_gcm.csv")) |> DataFrame).GCM
ssps = ["SSP126", "SSP245", "SSP370", "SSP585"]

# Run model
for ssp in ssps

    laborloss_gtap_frac = DataFrame()
    laborcost = DataFrame()
    T = DataFrame()

    for (i, gcm) in enumerate(gcms)

        m = get_model(; socioeconomics_source = :SSP, SSP_scenario = ssp)
        update_param!(m, :Labor, :gcm, i)
        run(m)

        # labor loss fraction
        df = getdataframe(m, :Labor, :laborloss_gtap_frac) |> @filter(_.time > 2019) |> DataFrame
        insertcols!(df, :gcm => gcm)
        append!(laborloss_gtap_frac, df)    

        # labor cost
        df = getdataframe(m, :Labor, :laborcost) |> @filter(_.time > 2019) |> DataFrame
        insertcols!(df, :gcm => gcm)
        append!(laborcost, df) 

        # T
        if i == 1 # just do this once
            df = getdataframe(m, :Labor, :temp_normalized)
            append!(T, df) 
        end
    end

    # Join temperature
    laborloss_gtap_frac = innerjoin(laborloss_gtap_frac, T, on = [:time])
    laborcost = innerjoin(laborcost, T, on = [:time])

    # Save CSVs
    laborloss_gtap_frac |> save(joinpath(output_dir, "laborloss_gtap_frac_$ssp.csv"))
    laborcost |> save(joinpath(output_dir, "laborcost_$ssp.csv"))

end

# Load DataFrames for graphs
laborloss_gtap_frac = load(joinpath(output_dir, "laborloss_gtap_frac_SSP245.csv")) |> DataFrame
laborcost = load(joinpath(output_dir, "laborcost_SSP245.csv")) |> DataFrame

min_val = minimum(laborloss_gtap_frac.temp_normalized)
max_val = maximum(laborloss_gtap_frac.temp_normalized)

# Labor Loss Fraction
n = 20_000
thin_rows = sample(collect(1:size(laborloss_gtap_frac,1)), n; replace = false)
laborloss_gtap_frac[thin_rows, :] |>
    @vlplot(
        title = ["Fractional Loss due to Labor Sector"; "All countries, Colored by GCM"],
        mark = {:circle, size = 5., clip = true},
        color = {"gcm:o", scale = {scheme = :spectral}, legend = {symbolOpacity = 1.}},
        x = {"temp_normalized:q", title = "Temperature Anomaly (deg C) Relative to 1995-2015", scale = {domain = (min_val, max_val)}},
        y = {"laborloss_gtap_frac", title = "Fractional Loss"}, 
        width = 500, 
        height = 250
    ) |> save(joinpath(output_dir, "laborloss_gtap_frac.png"), ppi = 300)

laborloss_gtap_frac |>
    @filter(_.gcm == "model_ensemble") |>
    @vlplot(
        title = ["Fractional Loss due to Labor Sector"; "Model Ensemble only, Colored by Country"],
        mark = {:circle, size = 5, clip = true},
        color = {"country:o", scale = {scheme = :category20}, legend = false},
        x = {"temp_normalized:q", title = "Temperature Anomaly (deg C) Relative to 1995-2015", scale = {domain = (min_val, max_val)}},
        y = {"laborloss_gtap_frac", title = "Fractional Loss"}, 
        width = 500, 
        height = 250
    ) |> save(joinpath(output_dir, "laborloss_gtap_frac_model_ensemble.png"), ppi = 300)

# Labor Costs
n = 20_000
thin_rows = sample(collect(1:size(laborcost,1)), n; replace = false)
laborcost[thin_rows, :] |>
    @vlplot(
        title = ["Labor Sector Costs"; "All countries, Colored by GCM"],
        mark = {:circle, size = 15., clip = true},
        color = {"gcm:o", scale = {scheme = :spectral}, legend = {symbolOpacity = 1.}},
        x = {"temp_normalized:q", title = "Temperature Anomaly (deg C) Relative to 1995-2015", scale = {domain = (min_val, max_val)}},
        y = {"laborcost", title = "Labor Cost (billions 2005 USD)"}, 
        width = 500, 
        height = 250
    ) |> save(joinpath(output_dir, "laborcost.png"), ppi = 300)

laborcost |>
    @filter(_.gcm == "model_ensemble") |>
    @vlplot(
        title = ["Labor Sector Costs"; "Model Ensemble only, Colored by Country"],
        mark = {:circle, size = 5., clip = true},
        color = {"country:o", scale = {scheme = :category20}, legend = false},
        x = {"temp_normalized:q", title = "Temperature Anomaly (deg C) Relative to 1995-2015", scale = {domain = (min_val, max_val)}},
        y = {"laborcost", title = "Labor Cost (billions 2005 USD)"}, 
        width = 500, 
        height = 250
    ) |> save(joinpath(output_dir, "laborcost_model_ensemble.png"), ppi = 300)

# By SSP
df = DataFrame()
for ssp in ssps
    df_ssp = load(joinpath(output_dir, "laborcost_$ssp.csv")) |> 
        @filter(_.gcm == "model_ensemble" && _.time <= 2100) |>
        DataFrame
    insertcols!(df_ssp, :ssp => ssp)
    append!(df, df_ssp)
end

countries = sample(unique(df.country), 16; replace = false)

df.time = Date.(df.time)
df |> 
    @filter(_.country in countries) |>
    @vlplot(
        resolve = {scale = {y = :independent}},
        title = ["Labor Sector Costs by SSP (billions 2005 USD)"; "Model Ensemble only, Colored by SSP"],
        mark = {:circle, size = 10.},
        color = {"ssp:n"},
        x = {"time:t", title = nothing},
        y = {"laborcost", title = nothing},
        width = 100, 
        height = 100,
        wrap = :country, 
        columns = 4
    ) |> save(joinpath(output_dir, "laborcost_model_ensemble_by_ssp_and_country.png"), ppi = 300)
    