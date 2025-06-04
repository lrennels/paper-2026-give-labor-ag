using Mimi, VegaLite

const pricelevel_2005_to_2020 = 113.648 / 87.504

output_dir = joinpath(@__DIR__, "output", "scc")
mkpath(output_dir)

# Load all functions
include(joinpath(@__DIR__, "..", "src", "main.jl"))

# Settings
num_trials = 1000
save_list = [
    (:DamageAggregator, :labor_damage),
    (:DamageAggregator, :agriculture_damage),
]

discount_rates = [
    (label = "1.5%", prtp = exp(9.149606e-05) - 1, eta = 1.016010e+00),
    (label = "2.0%", prtp = exp(0.001972641) - 1, eta = 1.244458999),
    (label = "2.5%", prtp = exp(0.004618784) - 1, eta = 1.421158088),
    (label = "3.0%", prtp = exp(0.007702711) - 1, eta = 1.567899391)
]

## -----------------------------------------------------------------------------
## Deterministic SCC
## TODO SSP 585 SCC seems low -- look into this
## -----------------------------------------------------------------------------

m = get_model()
scc = compute_scc(m, year = 2020)

for ssp in ["SSP126", "SSP245", "SSP370", "SSP585"]
    m = get_model(; socioeconomics_source = :SSP, SSP_scenario = ssp)
    scc = compute_scc(m, year = 2020) .* pricelevel_2005_to_2020
    println("Deterministic SCC for $ssp = $scc")
end

## -----------------------------------------------------------------------------
# Monte Carlo SCC
## TODO the ag sector seems too low
## -----------------------------------------------------------------------------

# get the data
m = get_model()
# update_param!(m, :DamageAggregator, :include_slr, false)
results = compute_scc(m;
                        year = 2020,
                        n = num_trials,
                        output_dir = output_dir,
                        save_list = save_list,
                        discount_rates = discount_rates,
                        compute_sectoral_values = true,
                        save_md = true
        )

# sectoral mean SCC bar plot
df = DataFrame()
for (k,v) in results[:scc]
    append!(df, 
                DataFrame(
                    dr = k.dr_label,
                    sector = k.sector,
                    expected_scc = v.expected_scc .* pricelevel_2005_to_2020,
                    se_expected_scc = v.se_expected_scc .* pricelevel_2005_to_2020
                )
            )
end

df |>   @filter(_.sector !== :total) |> 
        @vlplot(
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
                            # gridOpacity = {
                            #     condition = {
                            #         test = "datum.value===0",
                            #         value = 1
                            #     },
                            #     value = 0
                            # }
                        },
                    },
                    width = 280/4,
                    height = {
                        step = 20
                    },
            :bar,
            x = {:sector, title = nothing},
            y = :expected_scc,
            color = :sector, 
            column = :dr
        ) |> save(joinpath(output_dir, "scc_groupedDR.png"), ppi = 300)


df |>   @filter(_.sector !== :total) |>
        @vlplot(
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
                        # gridOpacity = {
                        #     condition = {
                        #         test = "datum.value===0",
                        #         value = 1
                        #     },
                        #     value = 0
                        # }
                    },
                },
                width = 280/5,
                height = {
                    step = 20
                },
            :bar,
            x = {:dr, title = nothing},
            y = :expected_scc,
            color = :sector, 
            column = :sector
        ) |> save(joinpath(output_dir, "scc_groupedSector.png"), ppi = 300)

# undiscounted marginal damages
df = DataFrame()
for (k,v) in results[:mds]
    vals = DataFrame(v, string.(collect(2020:2300)))
    insertcols!(vals, 1, :trial => collect(1:num_trials))
    vals = stack(vals, Not(:trial))
    insertcols!(vals, 1, :sector => k.sector)
    vals.variable = parse.(Int64, vals.variable)
    vals.value = vals.value .* pricelevel_2005_to_2020
    append!(df, vals)
end

df |> 
        @filter(_.variable <= 2100) |>
        @vlplot(
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
                                # gridOpacity = {
                                #     condition = {
                                #         test = "datum.value===0",
                                #         value = 1
                                #     },
                                #     value = 0
                                # }
                            },
                        },
                        width = 280/4,
                        height = {
                            step = 20
                        },
                resolve = {scale = {y = :independent}},
                :line,
                x = :variable,
                y = :value,
                color = :sector,
                strokeWidth = {"trial", scale = {range = [0.2]}, legend = false}, # hack to get lines to show up differently
                width = 300,
                height = 150,
                wrap = :sector,
                columns = 3
            ) |> save(joinpath(output_dir, "mds_unidscounted.png"), ppi = 300)

df_quantiles = df |>
        @groupby({_.sector, _.variable}) |>
        @map({key(_)..., q05 = quantile(_.value, 0.05), q25 = quantile(_.value, 0.25), median = quantile(_.value, 0.5), q75 = quantile(_.value, 0.75), q95 = quantile(_.value, 0.95), mean = mean(_.value)}) |>
        DataFrame

for sector in unique(df_quantiles.sector), endyear in [2100,2300]
    df_quantiles |>
        @filter(_.sector == sector && _.variable <= endyear) |>
        @vlplot(
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
                layer = [
                    @vlfrag(
                        title = "$sector",
                        mark = :line,
                        x = {"variable:q", title = "Year"},
                        y = {"median:q",title = "Marginal Damages"},
                    ),
                    @vlfrag(
                        mark = {:errorband, opacity = 0.1},
                        x = {"variable:q", title = "Year"},
                        y = {"q05:q", title = "Marginal Damages"},
                        y2 = "q95:q"
                    ),
                    @vlfrag(
                        mark = {:errorband, opacity = 0.3},
                        x = {"variable:q", title = "Year"},
                        y = {"q25:q", title = "Marginal Damages"},
                        y2 = "q75:q"
                    )
                ]
        ) |> save(joinpath(output_dir, "mds_unidscounted_$(sector)_to$endyear.png"), ppi = 300)
end

# sectoral SCC box plots
df_final = DataFrame(scc = Float64[], sector = Symbol[], dr = String[])

for (k, v) in results[:scc]
    df = DataFrame(scc = v.sccs .* pricelevel_2005_to_2020)
    df[!, :sector] .= k.sector
    df[!, :dr] .= k.dr_label

    append!(df_final, df)
end
df_final.sector = string.(df_final.sector)

df_quantiles = df_final |>
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

p = df_quantiles |> @vlplot(
                        y = {"sector:n", axis = {domain = false, ticks = false, title = nothing, grid = false}},
                        color = {"sector:n", legend = nothing, scale = {range = ["#758aad", "#bfa468", "#7fa89f", "#b38f8d", "#7a946c", "#7B5EA6"]}},
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
            ) |> save(joinpath(output_dir, "scc_2pct_boxplots.png"), ppi = 300)

