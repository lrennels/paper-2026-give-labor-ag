using Mimi, VegaLite, Random, Query, DataFrames

# For comparison with EPA (2023) report outputs
epa2023_output_dir = joinpath(@__DIR__, "..", "output", "epa2023")

for labor_function in labor_functions

    # Primary outputs
    output_dir = joinpath(@__DIR__, "..", "output", "scc", "pulse$(year)_n$(num_trials)_$(labor_function)_seed$(seed)")
    mkpath(output_dir)

    ## -----------------------------------------------------------------------------
    ## Run Model
    ## -----------------------------------------------------------------------------

    m = get_model(socioeconomics_source = :RFF, labor_damage_function = labor_function)
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
                    compute_labor_country_sccs = true
                )

    ## -----------------------------------------------------------------------------
    ## Save SCC Results
    ## -----------------------------------------------------------------------------

    df_final = DataFrame(scc = Float64[], sector = Symbol[], dr = String[])

    for (k, v) in results[:scc]
        df = DataFrame(scc = v.sccs .* pricelevel_2005_to_2020)
        df[!, :sector] .= k.sector
        df[!, :dr] .= k.dr_label
        append!(df_final, df)
    end

    df_final |> save(joinpath(output_dir, "sccs.csv"))

    # Save summary of all SCCs
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

    ## -----------------------------------------------------------------------------
    ## Save country-level Labor SCC Results
    ## -----------------------------------------------------------------------------

    # Save labor country-level SCCs
    df_final_labor_country = DataFrame(country = String[], trial = Int[], scc = Float64[], dr = String[])

    for (k, v) in results[:labor_country_sccs]
        df = DataFrame(v.sccs .* pricelevel_2005_to_2020, Symbol.(1:num_trials))
        insertcols!(df, 1, :country => dim_keys(m, :country))
        df = stack(df, Not(:country), variable_name = :trial, value_name = :scc)
        df[!, :dr] .= k.dr_label
        df.trial .= parse.(Int, df.trial)
        append!(df_final_labor_country, df)
    end

    df_final_labor_country |> save(joinpath(output_dir, "sccs_labor_country.csv"))

    # Save summary of labor country-level SCCs
    df_final_labor_country = DataFrame(country = String[], expected_scc = Float64[], dr = String[], se_expected_scc = Float64[])

    for (k, v) in results[:labor_country_sccs]
        df = DataFrame(
                        country = dim_keys(m, :country),
                        expected_scc = vec(v.expected_scc .* pricelevel_2005_to_2020),
                        dr = k.dr_label,
                        se_expected_scc = vec(v.se_expected_scc .* pricelevel_2005_to_2020)
        )
        append!(df_final_labor_country, df)
    end

    df_final_labor_country |> save(joinpath(output_dir, "expected_scc_labor_country.csv"))

    ## -----------------------------------------------------------------------------
    ## Figures
    ## -----------------------------------------------------------------------------

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

    # Plot aggregated data

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

    # Plot epa2023 data

    data = load(joinpath(epa2023_output_dir, "sc-CO2-give-2020-n10000.csv"), colparsers = Dict(:dr => String)) |> DataFrame # loaded from the EPA (2023) Github repository replication code

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

    # Plot our data and EPA data together

    aggregated_data_new = load(joinpath(output_dir, "figure_data_aggregated.csv")) |> DataFrame
    aggregated_data_new.dr .= "2.0% Ramsey"
    rename!(aggregated_data_new, :dr => :discount_rate)

    aggregated_data_rennert = load(joinpath(epa2023_output_dir, "figure3_data_aggregated.csv")) |>
                                @filter(_.sector in ["Agriculture", "Total"]) |>
                                DataFrame
    aggregated_data_rennert.sector = replace(aggregated_data_rennert.sector, "Total" => "Total (Rennert et al. 2022)", "Agriculture" => "Agriculture (Rennert et al. 2022)")

    df = vcat(aggregated_data_new, aggregated_data_rennert)

    p = df |> @vlplot(
                                y = {"sector:n", axis = {domain = false, ticks = false, title = nothing, grid = false}},
                                color = {"sector:n", legend = nothing, scale = {range = ["#6f85a0", "#abbcd2", "#d8d3cd", "#6c8267", "#d8d3cd", "#d8d3cd", "#b58260", "#f2caa2"]}},
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
                                    step = 25
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
                            
    p |> save(joinpath(output_dir, "grouped_fig.png"), ppi = 300)

end