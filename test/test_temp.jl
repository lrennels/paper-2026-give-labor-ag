using Mimi, VegaLite, StatsBase, Dates, DataFrames, Query

output_dir = joinpath(@__DIR__, "output", "temp")
mkpath(output_dir)

# Temp norm range for labor
T_range = collect(1995:2015)
num_trials = 1_000

# Get temperature average -- note all use the same emissions up until 2020 so
# we don't need to test the RFFSPs vs different SSPs
m = get_model()
update_param!(m, :DamageAggregator, :include_slr, false)

save_list = [
    (:temperature, :T),
    (:TempNorm_1995to2015, :global_temperature_norm)
]

results = run_mcs(; trials = num_trials, output_dir = output_dir, save_list = save_list);

# Gather data
df1 = load(joinpath(output_dir, "results", "temperature_T.csv")) |> 
        DataFrame
insertcols!(df1, :variable => "Relative to Preindustrial")
T_norm = round(mean((df1 |> @filter(_.time in T_range) |> DataFrame).T), digits = 4)
df1_quant = df1 |>
                @groupby({_.time, _.variable}) |>
                @map({key(_)..., q05 = quantile(_.T, 0.05), q25 = quantile(_.T, 0.25), median = quantile(_.T, 0.5), q75 = quantile(_.T, 0.75), q95 = quantile(_.T, 0.95), mean = mean(_.T)}) |>
                DataFrame

df2 = load(joinpath(output_dir, "results", "TempNorm_1995to2015_global_temperature_norm.csv")) |> 
        @filter(_.time >= T_range[end]) |>
        DataFrame
rename!(df2, :global_temperature_norm => :T)
insertcols!(df2, :variable => "Relative to 1995-2015")
df2.T = Float64.(df2.T)
df2_quant = df2 |>
                @groupby({_.time, _.variable}) |>
                @map({key(_)..., q05 = quantile(_.T, 0.05), q25 = quantile(_.T, 0.25), median = quantile(_.T, 0.5), q75 = quantile(_.T, 0.75), q95 = quantile(_.T, 0.95), mean = mean(_.T)}) |>
                DataFrame

# Graph 2015 - 2300 with both variables
df = vcat(df1_quant, df2_quant)
df.time = Date.(df.time)
df |>
        @vlplot(
            config = {
                        font = "Helvetica",
                        # style = {cell = {stroke = :transparent}},
                        axis = {
                            labelFontSize = 7,
                            titleFontSize = 7,
                            domainColor = :black,
                            tickColor = :black,
                            titleFontWeight = :normal
                        },
                        legend = {
                            labelFontSize = 7,
                            titleFontSize = 7,
                            # orient = "bottom-right",
                            titleFontWeight = :normal,
                            symbolSize = 25.,
                            symbolOpacity = 1.
                        },
                        text = {
                            fontSize = 7
                        },
                        title = {
                            fontSize = 8,
                            anchor = :start
                        }
                },
                width = 500,
                height = 250,
                x = {"time",timeUnit = :year,title = "year"},
                title = ["FaIR v1.6.2 Temperature Anomaly (n = 1k)", "Solid mean, dashed median, bands at 25-75% and 5-95%", "1995-2005 average = $T_norm °C"],
                color = :variable, 
                layer = [
                    @vlfrag(
                        mark = {:errorband, opacity = 0.1},
                        y = {"q05:q",axis = {grid = true}, title = "Temperature Anomaly (°C)"},
                        y2 = "q95:q"
                    ),
                    @vlfrag(
                        mark = {:errorband, opacity = 0.2},
                        y = {"q25:q",axis = {grid = true}, title = "Temperature Anomaly (°C)"},
                        y2 = "q75:q"
                    ),
                    @vlfrag(
                        mark = {:line, strokeDash = "4,4"},
                        y = {"median:q",title = title = "Temperature Anomaly (°C)"}
                    ),
                    @vlfrag(
                        mark = :line,
                        y = {"mean:q",title = title = "Temperature Anomaly (°C)"}
                    ) 
                ]
            ) |>
            save(joinpath(output_dir, "T_anomaly.svg"))

# Graph just Relative to Preindustrial
df |>   
        @filter(_.time in Date.(T_range) && _.variable == "Relative to Preindustrial") |>
        @vlplot(
            config = {
                        font = "Helvetica",
                        # style = {cell = {stroke = :transparent}},
                        axis = {
                            labelFontSize = 7,
                            titleFontSize = 7,
                            domainColor = :black,
                            tickColor = :black,
                            titleFontWeight = :normal
                        },
                        legend = {
                            labelFontSize = 7,
                            titleFontSize = 7,
                            # orient = "bottom-right",
                            titleFontWeight = :normal,
                            symbolSize = 25.
                        },
                        text = {
                            fontSize = 7
                        },
                        title = {
                            fontSize = 8,
                            anchor = :start
                        }
                },
                width = 500,
                height = 250,
                x = {"time",timeUnit = :year,title = "year"},
                title = ["FaIR v1.6.2 Temperature Anomaly (n = 1k)", "Solid mean, dashed median, bands at 25-75% and 5-95%", "1995-2005 average = $T_norm °C"],
                layer = [
                    @vlfrag(
                        mark = {:errorband, opacity = 0.1},
                        y = {"q05:q",axis = {grid = true}, title = "Temperature Anomaly (°C)"},
                        y2 = "q95:q"
                    ),
                    @vlfrag(
                        mark = {:errorband, opacity = 0.2},
                        y = {"q25:q",axis = {grid = true}, title = "Temperature Anomaly (°C)"},
                        y2 = "q75:q"
                    ),
                    @vlfrag(
                        mark = {:line, strokeDash = "4,4"},
                        y = {"median:q",title = title = "Temperature Anomaly (°C)"}
                    ),
                    @vlfrag(
                        mark = :line,
                        y = {"mean:q",title = title = "Temperature Anomaly (°C)"}
                    ) 
                ]
            ) |>
            save(joinpath(output_dir, "T_anomaly_1995_2015.svg"))