using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using Mimi, VegaLite, Random, Query, DataFrames

const pricelevel_2005_to_2020 = 113.648 / 87.504
const seed = 14523438

# Load all functions
include(joinpath(@__DIR__, "..", "src", "main.jl"))

# Settings
year = 2020
num_trials = 10_000

output_dir = joinpath(@__DIR__, "..", "output", "scc", "pulse$(year)_n$(num_trials)_seed$(seed)")
mkpath(output_dir)

discount_rates = [
    (label = "1.5%", prtp = exp(9.149606e-05) - 1, eta = 1.016010e+00),
    (label = "2.0%", prtp = exp(0.001972641) - 1, eta = 1.244458999),
    (label = "2.5%", prtp = exp(0.004618784) - 1, eta = 1.421158088),
    (label = "3.0%", prtp = exp(0.007702711) - 1, eta = 1.567899391)
]

# Run model
m = get_model(socioeconomics_source = :RFF)
Random.seed!(seed)
results = compute_scc(m;
                year = year,
                last_year = 2300,
                discount_rates = discount_rates,
                fair_parameter_set = :random,
                rffsp_sampling = :random,
                n = num_trials,
                gas = :CO2,
                output_dir = nothing,
                save_md = false,
                save_cpc = false,
                compute_sectoral_values = true,
                CIAM_foresight = :perfect,
                CIAM_GDPcap = true,
                pulse_size = 1e-4,
            )

# Save all SCCs
df_final = DataFrame(scc = Float64[], sector = Symbol[], dr = String[])

for (k, v) in results[:scc]
    df = DataFrame(scc = v.sccs .* pricelevel_2005_to_2020)
    df[!, :sector] .= k.sector
    df[!, :dr] .= k.dr_label
    append!(df_final, df)
end

df_final |> save(joinpath(output_dir, "sccs.csv"))

# Save summary
df_final = DataFrame(expected_scc = Float64[], sector = Symbol[], dr = String[], se_expected_scc = Float64[])

for (k, v) in results[:scc]
    df = DataFrame(
                    expected_scc = v.expected_scc .* pricelevel_2005_to_2020,
                    sector = k.sector,
                    dr = k.dr_label,
                    se_expected_scc = v.se_expected_scc .* pricelevel_2005_to_2020
    )
    append!(df_final, df)
end

df_final |> save(joinpath(output_dir, "expected_scc.csv"))

# Save aggregated data for figure
data = load(joinpath(output_dir, "sccs.csv"), colparsers = Dict(:dr => String)) |> DataFrame

aggregated_data = data |>
                        @filter(_.dr == "2.0%") |>
                        @mutate(sector =
                            _.sector == "total" ? "Total" :
                            _.sector == "energy" ? "Energy" :
                            _.sector == "cromar_mortality" ? "Mortality" :
                            _.sector == "agriculture" ? "Agriculture" :
                            _.sector == "labor" ? "Labor" :
                            _.sector == "slr" ? "Sea-level rise" : error("Unknown sector")) |>
                        @groupby({_.dr, _.sector}) |>
                        @map({key(_)..., q05 = quantile(_.scc, 0.05), q25 = quantile(_.scc, 0.25), median = quantile(_.scc, 0.5), q75 = quantile(_.scc, 0.75), q95 = quantile(_.scc, 0.95), mean = mean(_.scc)}) |>
                        DataFrame

aggregated_data |> save(joinpath(output_dir, "figure_data_aggregated.csv"))

# Plot
p = aggregated_data |> @vlplot(
                               y = {"sector:n", axis = {domain = false, ticks = false, title = nothing, grid = false}},
                               color = {"sector:n", legend = nothing, scale = {range = ["#abbcd2", "#f2caa2", "#c2dbd9", "#f1d0cf", "#d9c2e6", "#b5cfac"]}},
                               config = {
                                   font = "Arial",
                                   style = {cell = {stroke = :transparent}},
                                   axis = {
                                       domainColor = :black,
                                       tickColor = :black,
                                       labelFontSize = 7,
                                       labelFlush = false,
                                       titleFontWeight = :normal,
                                       titleFontSize = 7,
                                       gridColor = {
                                           value = "#ddd"
                                       },
                                       gridOpacity = {
                                           condition = {
                                               test = "datum.value===0",
                                               value = 1
                                           },
                                           value = 0
                                       }
                                   },
                               },
                               width = 280,
                               height = {
                                   step = 20
                               }) +
                           @vlplot(:rule, x = {
                                   "q05:q",
                                   axis = {title = "SC-CO₂ (US\$ per tonne of CO₂)", grid = true}
                               },
                               x2 = "q95:q"
                           ) +
                           @vlplot(
                               {
                                   :bar,
                                   size = 13
                               },
                               x = "q25:q",
                               x2 = "q75:q"
                           ) +
                           @vlplot(
                               {
                                   :tick,
                               },
                               x = "median:q",
                               color = {
                                   value = :white
                               },
                               size = {
                                   condition = {
                                       test = "(datum.q75-datum.q25) < 2",
                                       value = 0
                                   },
                                   value = 13
                               }
                           ) +
                           @vlplot(
                               {
                                   :text,
                                   fontSize = 7,
                                   dy = -12
                               },
                               x = "mean:q",
                               text = {
                                   "mean:q",
                                   format = "\$.0f"
                               },
                               color = {value = :black}
                           ) +
                           @vlplot(
                               {
                                   :point,
                                   shape = :diamond,
                                   strokeWidth = 1
                               },
                               x = "mean:q",
                               color = {value = :black}
                           )

p |> save(joinpath(output_dir, "fig.svg"))

# Plot epa2023 et al. 2022 data
epa2023_output_dir = joinpath(@__DIR__, "..", "output", "epa2023")

data = load(joinpath(epa2023_output_dir, "sc-CO2-give-2020-n10000.csv"), colparsers = Dict(:dr => String)) |> DataFrame

aggregated_data = data |>
                        @filter(_.discount_rate == "2.0% Ramsey") |>
                        @mutate(sector =
                            _.sector == "total" ? "Total" :
                            _.sector == "energy" ? "Energy" :
                            _.sector == "cromar_mortality" ? "Mortality" :
                            _.sector == "agriculture" ? "Agriculture" :
                            _.sector == "slr" ? "Sea-level rise" : error("Unknown sector")) |>
                        @groupby({_.discount_rate, _.sector}) |>
                        @map({key(_)..., q05 = quantile(_.scghg, 0.05), q25 = quantile(_.scghg, 0.25), median = quantile(_.scghg, 0.5), q75 = quantile(_.scghg, 0.75), q95 = quantile(_.scghg, 0.95), mean = mean(_.scghg)}) |>
                        DataFrame
aggregated_data |> save(joinpath(epa2023_output_dir, "figure3_data_aggregated.csv"))

aggregated_data = load(joinpath(epa2023_output_dir, "figure3_data_aggregated.csv")) |> DataFrame

p = aggregated_data |> @vlplot(
                               y = {"sector:n", axis = {domain = false, ticks = false, title = nothing, grid = false}},
                               color = {"sector:n", legend = nothing, scale = {range = ["#abbcd2", "#f2caa2", "#c2dbd9", "#f1d0cf", "#b5cfac"]}},
                               config = {
                                   font = "Arial",
                                   style = {cell = {stroke = :transparent}},
                                   axis = {
                                       domainColor = :black,
                                       tickColor = :black,
                                       labelFontSize = 7,
                                       labelFlush = false,
                                       titleFontWeight = :normal,
                                       titleFontSize = 7,
                                       gridColor = {
                                           value = "#ddd"
                                       },
                                       gridOpacity = {
                                           condition = {
                                               test = "datum.value===0",
                                               value = 1
                                           },
                                           value = 0
                                       }
                                   },
                               },
                               width = 280,
                               height = {
                                   step = 20
                               }) +
                           @vlplot(:rule, x = {
                                   "q05:q",
                                   axis = {title = "SC-CO₂ (US\$ per tonne of CO₂)", grid = true}
                               },
                               x2 = "q95:q"
                           ) +
                           @vlplot(
                               {
                                   :bar,
                                   size = 13
                               },
                               x = "q25:q",
                               x2 = "q75:q"
                           ) +
                           @vlplot(
                               {
                                   :tick,
                               },
                               x = "median:q",
                               color = {
                                   value = :white
                               },
                               size = {
                                   condition = {
                                       test = "(datum.q75-datum.q25) < 2",
                                       value = 0
                                   },
                                   value = 13
                               }
                           ) +
                           @vlplot(
                               {
                                   :text,
                                   fontSize = 7,
                                   dy = -12
                               },
                               x = "mean:q",
                               text = {
                                   "mean:q",
                                   format = "\$.0f"
                               },
                               color = {value = :black}
                           ) +
                           @vlplot(
                               {
                                   :point,
                                   shape = :diamond,
                                   strokeWidth = 1
                               },
                               x = "mean:q",
                               color = {value = :black}
                           )

p |> save(joinpath(epa2023_output_dir, "fig3.svg"))
