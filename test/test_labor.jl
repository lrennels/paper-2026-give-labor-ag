using Mimi, VegaLite, StatsBase, Dates

output_dir = joinpath(@__DIR__, "output", "labor")
mkpath(output_dir)

# Load all functions
include(joinpath(@__DIR__, "..", "src", "main.jl"))

# Options
gcms = (load(joinpath(@__DIR__, "..", "data", "dimension_gcm.csv")) |> DataFrame).GCM
ssps = ["SSP126", "SSP245", "SSP370", "SSP585"]

# For thinning rows
n = 20_000

# Run model
for ssp in ssps

    println("Running SSP: $ssp")

    laborloss_ag_gtap_frac = DataFrame()
    laborloss_nonag_gtap_frac = DataFrame()
    
    laborcost_ag = DataFrame()
    laborcost_nonag = DataFrame()
    laborcost = DataFrame()

    T = DataFrame()

    for (i, gcm) in enumerate(gcms)

        m = get_model(; socioeconomics_source = :SSP, SSP_scenario = ssp)
        update_param!(m, :Labor, :gcm, i)
        run(m)

        # labor loss fractions
        df = getdataframe(m, :Labor, :laborloss_ag_gtap_frac) |> @filter(_.time > 2019) |> DataFrame
        insertcols!(df, :gcm => gcm)
        append!(laborloss_ag_gtap_frac, df)    

        df = getdataframe(m, :Labor, :laborloss_nonag_gtap_frac) |> @filter(_.time > 2019) |> DataFrame
        insertcols!(df, :gcm => gcm)
        append!(laborloss_nonag_gtap_frac, df)    

        # labor cost
        df = getdataframe(m, :Labor, :laborcost_ag) |> @filter(_.time > 2019) |> DataFrame
        insertcols!(df, :gcm => gcm)
        append!(laborcost_ag, df) 

        df = getdataframe(m, :Labor, :laborcost_nonag) |> @filter(_.time > 2019) |> DataFrame
        insertcols!(df, :gcm => gcm)
        append!(laborcost_nonag, df) 

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
    laborloss_ag_gtap_frac = innerjoin(laborloss_ag_gtap_frac, T, on = [:time])
    laborloss_nonag_gtap_frac = innerjoin(laborloss_nonag_gtap_frac, T, on = [:time])
    laborcost_ag = innerjoin(laborcost_ag, T, on = [:time])
    laborcost_nonag = innerjoin(laborcost_nonag, T, on = [:time])
    laborcost = innerjoin(laborcost, T, on = [:time])

    # Save CSVs
    laborloss_ag_gtap_frac |> save(joinpath(output_dir, "laborloss_ag_gtap_frac_$ssp.csv"))
    laborloss_nonag_gtap_frac |> save(joinpath(output_dir, "laborloss_nonag_gtap_frac_$ssp.csv"))
    laborcost_ag |> save(joinpath(output_dir, "laborcost_ag_$ssp.csv"))
    laborcost_nonag |> save(joinpath(output_dir, "laborcost_nonag_$ssp.csv"))
    laborcost |> save(joinpath(output_dir, "laborcost_$ssp.csv"))

end

# Load DataFrames for graphs
laborloss_ag_gtap_frac = load(joinpath(output_dir, "laborloss_ag_gtap_frac_SSP245.csv")) |> DataFrame
laborloss_nonag_gtap_frac = load(joinpath(output_dir, "laborloss_nonag_gtap_frac_SSP245.csv")) |> DataFrame
laborcost_ag = load(joinpath(output_dir, "laborcost_ag_SSP245.csv")) |> DataFrame
laborcost_nonag = load(joinpath(output_dir, "laborcost_nonag_SSP245.csv")) |> DataFrame
laborcost = load(joinpath(output_dir, "laborcost_SSP245.csv")) |> DataFrame

min_val = minimum(laborloss_ag_gtap_frac.temp_normalized)
max_val = maximum(laborloss_ag_gtap_frac.temp_normalized)

# Labor Loss Fraction

# ag
thin_rows = sample(collect(1:size(laborloss_ag_gtap_frac,1)), n; replace = false)
laborloss_ag_gtap_frac[thin_rows, :] |>
    @vlplot(
        title = ["Fractional Loss due to Ag Labor Sector"; "All countries, Colored by GCM"],
        mark = {:circle, size = 5., clip = true},
        color = {"gcm:o", scale = {scheme = :spectral}, legend = {symbolOpacity = 1.}},
        x = {"temp_normalized:q", title = "Temperature Anomaly (deg C) Relative to 1995-2015", scale = {domain = (min_val, max_val)}},
        y = {"laborloss_ag_gtap_frac", title = "Fractional Loss"}, 
        width = 500, 
        height = 250
    ) |> save(joinpath(output_dir, "laborloss_ag_gtap_frac.png"), ppi = 300)

laborloss_ag_gtap_frac |>
    @filter(_.gcm == "model_ensemble") |>
    @vlplot(
        title = ["Fractional Loss due to Ag Labor Sector"; "Model Ensemble only, Colored by Country"],
        mark = {:circle, size = 5, clip = true},
        color = {"country:o", scale = {scheme = :category20}, legend = false},
        x = {"temp_normalized:q", title = "Temperature Anomaly (deg C) Relative to 1995-2015", scale = {domain = (min_val, max_val)}},
        y = {"laborloss_ag_gtap_frac", title = "Fractional Loss"}, 
        width = 500, 
        height = 250
    ) |> save(joinpath(output_dir, "laborloss_ag_gtap_frac_model_ensemble.png"), ppi = 300)

# non ag
thin_rows = sample(collect(1:size(laborloss_nonag_gtap_frac,1)), n; replace = false)
laborloss_nonag_gtap_frac[thin_rows, :] |>
    @vlplot(
        title = ["Fractional Loss due to NonAgLabor Sector"; "All countries, Colored by GCM"],
        mark = {:circle, size = 5., clip = true},
        color = {"gcm:o", scale = {scheme = :spectral}, legend = {symbolOpacity = 1.}},
        x = {"temp_normalized:q", title = "Temperature Anomaly (deg C) Relative to 1995-2015", scale = {domain = (min_val, max_val)}},
        y = {"laborloss_nonag_gtap_frac", title = "Fractional Loss"}, 
        width = 500, 
        height = 250
    ) |> save(joinpath(output_dir, "laborloss_nonag_gtap_frac.png"), ppi = 300)

laborloss_nonag_gtap_frac |>
    @filter(_.gcm == "model_ensemble") |>
    @vlplot(
        title = ["Fractional Loss due to NonAg Labor Sector"; "Model Ensemble only, Colored by Country"],
        mark = {:circle, size = 5, clip = true},
        color = {"country:o", scale = {scheme = :category20}, legend = false},
        x = {"temp_normalized:q", title = "Temperature Anomaly (deg C) Relative to 1995-2015", scale = {domain = (min_val, max_val)}},
        y = {"laborloss_nonag_gtap_frac", title = "Fractional Loss"}, 
        width = 500, 
        height = 250
    ) |> save(joinpath(output_dir, "laborloss_nonag_gtap_frac_model_ensemble.png"), ppi = 300)

# Labor Costs

# ag
thin_rows = sample(collect(1:size(laborcost_ag,1)), n; replace = false)
laborcost_ag[thin_rows, :] |>
    @vlplot(
        title = ["Ag Labor Sector Costs"; "All countries, Colored by GCM"],
        mark = {:circle, size = 15., clip = true},
        color = {"gcm:o", scale = {scheme = :spectral}, legend = {symbolOpacity = 1.}},
        x = {"temp_normalized:q", title = "Temperature Anomaly (deg C) Relative to 1995-2015", scale = {domain = (min_val, max_val)}},
        y = {"laborcost_ag", title = "Labor Cost (billions 2005 USD)"}, 
        width = 500, 
        height = 250
    ) |> save(joinpath(output_dir, "laborcost_ag.png"), ppi = 300)

laborcost_ag |>
    @filter(_.gcm == "model_ensemble") |>
    @vlplot(
        title = ["Ag Labor Sector Costs"; "Model Ensemble only, Colored by Country"],
        mark = {:circle, size = 5., clip = true},
        color = {"country:o", scale = {scheme = :category20}, legend = false},
        x = {"temp_normalized:q", title = "Temperature Anomaly (deg C) Relative to 1995-2015", scale = {domain = (min_val, max_val)}},
        y = {"laborcost_ag", title = "Labor Cost (billions 2005 USD)"}, 
        width = 500, 
        height = 250
    ) |> save(joinpath(output_dir, "laborcost_ag_model_ensemble.png"), ppi = 300)

# nonag
thin_rows = sample(collect(1:size(laborcost_nonag,1)), n; replace = false)
laborcost_nonag[thin_rows, :] |>
    @vlplot(
        title = ["NonAg Labor Sector Costs"; "All countries, Colored by GCM"],
        mark = {:circle, size = 15., clip = true},
        color = {"gcm:o", scale = {scheme = :spectral}, legend = {symbolOpacity = 1.}},
        x = {"temp_normalized:q", title = "Temperature Anomaly (deg C) Relative to 1995-2015", scale = {domain = (min_val, max_val)}},
        y = {"laborcost_nonag", title = "Labor Cost (billions 2005 USD)"}, 
        width = 500, 
        height = 250
    ) |> save(joinpath(output_dir, "laborcost_nonag.png"), ppi = 300)

laborcost_nonag |>
    @filter(_.gcm == "model_ensemble") |>
    @vlplot(
        title = ["NonAg Labor Sector Costs"; "Model Ensemble only, Colored by Country"],
        mark = {:circle, size = 5., clip = true},
        color = {"country:o", scale = {scheme = :category20}, legend = false},
        x = {"temp_normalized:q", title = "Temperature Anomaly (deg C) Relative to 1995-2015", scale = {domain = (min_val, max_val)}},
        y = {"laborcost_nonag", title = "Labor Cost (billions 2005 USD)"}, 
        width = 500, 
        height = 250
    ) |> save(joinpath(output_dir, "laborcost_nonag_model_ensemble.png"), ppi = 300)

# total
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

# ag
df = DataFrame()
for ssp in ssps
    df_ssp = load(joinpath(output_dir, "laborcost_ag_$ssp.csv")) |> 
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
        title = ["Ag Labor Sector Costs by SSP (billions 2005 USD)"; "Model Ensemble only, Colored by SSP"],
        mark = {:circle, size = 10.},
        color = {"ssp:n"},
        x = {"time:t", title = nothing},
        y = {"laborcost_ag", title = nothing},
        width = 100, 
        height = 100,
        wrap = :country, 
        columns = 4
    ) |> save(joinpath(output_dir, "laborcost_ag_model_ensemble_by_ssp_and_country.png"), ppi = 300)


# nonag
df = DataFrame()
for ssp in ssps
    df_ssp = load(joinpath(output_dir, "laborcost_nonag_$ssp.csv")) |> 
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
        title = ["NonAg Labor Sector Costs by SSP (billions 2005 USD)"; "Model Ensemble only, Colored by SSP"],
        mark = {:circle, size = 10.},
        color = {"ssp:n"},
        x = {"time:t", title = nothing},
        y = {"laborcost_nonag", title = nothing},
        width = 100, 
        height = 100,
        wrap = :country, 
        columns = 4
    ) |> save(joinpath(output_dir, "laborcost_nonag_model_ensemble_by_ssp_and_country.png"), ppi = 300)

# total
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
