using Mimi, VegaLite, StatsBase

output_dir = joinpath(@__DIR__, "output")
mkpath(output_dir)

# Load all functions
include(joinpath(@__DIR__, "..", "src", "main.jl"))

# GCM options
gcms = (load(joinpath(@__DIR__, "..", "data", "dimension_gcm.csv")) |> DataFrame).GCM

# Run model
laborloss_gtap_frac = DataFrame()
laborcost = DataFrame()
T = DataFrame()

for (i, gcm) in enumerate(gcms)

    println("Running gcm $gcm and saving labor variables.")

    m = get_model()
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
        df = getdataframe(m, :Labor, :temp)
        append!(T, df) 
    end
end

# Join temperature
laborloss_gtap_frac = innerjoin(laborloss_gtap_frac, T, on = [:time])
laborcost = innerjoin(laborcost, T, on = [:time])

# Save CSVs
laborloss_gtap_frac |> save(joinpath(output_dir, "laborloss_gtap_frac.csv"))
laborcost |> save(joinpath(output_dir, "laborcost.csv"))

# Labor Loss Fraction
n = 10_000
thin_rows = sample(collect(1:size(laborloss_gtap_frac,1)), n; replace = false)
laborloss_gtap_frac[thin_rows, :] |>
    @vlplot(
        title = ["Fractional Loss due to Labor Sector"; "All countries, Colored by GCM"],
        mark = {:circle, size = 5.},
        color = {"gcm:o", scale = {scheme = :spectral}, legend = {symbolOpacity = 1.}},
        x = {"temp:q", title = "Temperature Anomaly (deg C)"},
        y = {"laborloss_gtap_frac", title = "Fractional Loss"}, 
        width = 500, 
        height = 250
    ) |> save(joinpath(output_dir, "laborloss_gtap_frac.png"), ppi = 300)

laborloss_gtap_frac |>
    @filter(_.gcm == "model_ensemble") |>
    @vlplot(
        title = ["Fractional Loss due to Labor Sector"; "Model Ensemble only, Colored by Country"],
        mark = {:circle, size = 2.5},
        color = {"country:o", scale = {scheme = :spectral}, legend = false},
        x = {"temp:q", title = "Temperature Anomaly (deg C)"},
        y = {"laborloss_gtap_frac", title = "Fractional Loss"}, 
        width = 500, 
        height = 250
    ) |> save(joinpath(output_dir, "laborloss_gtap_frac_model_ensemble.png"), ppi = 300)

# Labor Costs
n = 10_000
thin_rows = sample(collect(1:size(laborcost,1)), n; replace = false)
laborcost[thin_rows, :] |>
    @vlplot(
        title = ["Labor Sector Costs"; "All countries, Colored by GCM"],
        mark = {:circle, size = 5.},
        color = {"gcm:o", scale = {scheme = :spectral}, legend = {symbolOpacity = 1.}},
        x = {"temp:q", title = "Temperature Anomaly (deg C)"},
        y = {"laborcost", title = "Labor Cost (billions 2005 USD)"}, 
        width = 500, 
        height = 250
    ) |> save(joinpath(output_dir, "laborcost.png"), ppi = 300)

laborcost |>
    @filter(_.gcm == "model_ensemble") |>
    @vlplot(
        title = ["Labor Sector Costs"; "Model Ensemble only, Colored by Country"],
        mark = {:circle, size = 2.5},
        color = {"country:o", scale = {scheme = :spectral}, legend = false},
        x = {"temp:q", title = "Temperature Anomaly (deg C)"},
        y = {"laborcost", title = "Labor Cost (billions 2005 USD)"}, 
        width = 500, 
        height = 250
    ) |> save(joinpath(output_dir, "laborcost_model_ensemble.png"), ppi = 300)
