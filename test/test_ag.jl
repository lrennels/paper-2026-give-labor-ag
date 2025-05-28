using Mimi, VegaLite, StatsBase

output_dir = joinpath(@__DIR__, "output", "ag")
mkpath(output_dir)

# Load all functions
include(joinpath(@__DIR__, "..", "src", "main.jl"))

# Options
pctiles = [:low, :mid, :high]
agrish_categories = [:crops, :agriculture]
ssps = ["SSP126", "SSP245", "SSP370", "SSP585"]

# Run model
for ssp in ssps
    for agrish_category in agrish_categories

        agrish = DataFrame()
        agloss_gtap_frac = DataFrame()
        agcost = DataFrame()
        T = DataFrame()

        for (i, pctile) in enumerate(pctiles)

            m = get_model(; agriculture_pctile = pctile, socioeconomics_source = :SSP, SSP_scenario = ssp)
            run(m)

            # labor loss fraction
            df = getdataframe(m, :Agriculture, :agloss_gtap_frac) |> @filter(_.time > 2019) |> DataFrame
            insertcols!(df, :pctile => pctile)
            append!(agloss_gtap_frac, df)    

            # ag cost
            df = getdataframe(m, :Agriculture, :agcost) |> @filter(_.time > 2019) |> DataFrame
            insertcols!(df, :pctile => pctile)
            append!(agcost, df) 

            # T
            if i == 1 # just do this once
                df = getdataframe(m, :Agriculture, :temp)
                append!(T, df) 

                df = getdataframe(m, :Agriculture, :agrish) |> @filter(_.time > 2019) |> DataFrame
                append!(agrish, df)    

            end
        end

        # Join temperature
        agloss_gtap_frac = innerjoin(agloss_gtap_frac, T, on = [:time])
        agcost = innerjoin(agcost, T, on = [:time])

        # Save CSVs
        agloss_gtap_frac |> save(joinpath(output_dir, "agloss_gtap_frac_$(ssp)_agrish$(agrish_category).csv"))
        agcost |> save(joinpath(output_dir, "agcost_$(ssp)_agrish$(agrish_category).csv"))
        agrish |> save(joinpath(output_dir, "agrish_$(ssp)_agrish$(agrish_category).csv"))
    end
end

# Load DataFrames for Graphs
agloss_gtap_frac = load(joinpath(output_dir, "agloss_gtap_frac_SSP245_agrishcrops.csv")) |> DataFrame
agcost = load(joinpath(output_dir, "agcost_SSP245_agrishcrops.csv")) |> DataFrame
agrish = load(joinpath(output_dir, "agrish_SSP245_agrishcrops.csv")) |> DataFrame

min_val = minimum(agloss_gtap_frac.temp)
max_val = maximum(agloss_gtap_frac.temp)

# Ag Loss Fraction
n = 20_000
thin_rows = sample(collect(1:size(agloss_gtap_frac,1)), n; replace = false)
agloss_gtap_frac[thin_rows, :] |>
    @vlplot(
        title = ["Fractional Loss due to Agricultural Sector"; "All countries, Colored by Percentile"],
        mark = {:circle, size = 50., opacity = 0.5, clip = true},
        color = {"pctile:n", legend = {symbolOpacity = 1.}},
        x = {"temp:q", title = "Temperature Anomaly (deg C)", scale = {domain = (min_val, max_val)}},
        y = {"agloss_gtap_frac", title = "Fractional Loss"}, 
        width = 250, 
        height = 500
    ) |> save(joinpath(output_dir, "agloss_gtap_frac.png"), ppi = 300)

agloss_gtap_frac |>
    @filter(_.pctile == "mid") |>
    @vlplot(
        title = ["Fractional Loss due to Agriculture Sector"; "50th Percentile only, Colored by Country"],
        mark = {:circle, size = 5, clip = true},
        color = {"country:o", scale = {scheme = :category20}, legend = false},
        x = {"temp:q", title = "Temperature Anomaly (deg C)", scale = {domain = (min_val, max_val)}},
        y = {"agloss_gtap_frac", title = "Fractional Loss"}, 
        width = 500, 
        height = 250
    ) |> save(joinpath(output_dir, "agloss_gtap_frac_model_ensemble.png"), ppi = 300)

# Ag Costs
n = 20_000
thin_rows = sample(collect(1:size(agcost,1)), n; replace = false)
agcost[thin_rows, :] |>
    @vlplot(
        title = ["Agriculture Sector Costs"; "All countries, Colored by GCM"],
        mark = {:circle, size = 25., opacity = 0.25, clip = true},
        color = {"pctile:n", legend = {symbolOpacity = 1.}},
        x = {"temp:q", title = "Temperature Anomaly (deg C)", scale = {domain = (min_val, max_val)}},
        y = {"agcost", title = "Agriculture Cost (billions 2005 USD)"}, 
        width = 500, 
        height = 250
    ) |> save(joinpath(output_dir, "agcost.png"), ppi = 300)

agcost |>
    @filter(_.pctile == "mid") |>
    @vlplot(
        title = ["Agriculture Sector Costs"; "50th Percentile only, Colored by Country"],
        mark = {:circle, size = 15., clip = true},
        color = {"country:n", legend = false},
        x = {"temp:q", title = "Temperature Anomaly (deg C)", scale = {domain = (min_val, max_val)}},
        y = {"agcost", title = "Ag Cost (billions 2005 USD)"}, 
        width = 500, 
        height = 250
    ) |> save(joinpath(output_dir, "agcost_mid_pctile.png"), ppi = 300)

agrish |>
    @vlplot(
            title = ["Agriculture Share"; "Colored by Country"],
            mark = {:line},
            color = {"country:n", legend = false},
            x = {"time:q", title = "Year"},
            y = {"agrish", title = "Share"}, 
            width = 500, 
            height = 250
    ) |> save(joinpath(output_dir, "agrish.png"), ppi = 300)
