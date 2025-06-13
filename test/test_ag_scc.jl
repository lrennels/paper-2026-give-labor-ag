using Mimi, MimiGIVE, Random, VegaLite

const pricelevel_2005_to_2020 = 113.648 / 87.504
const seed = 12345

top_output_dir = joinpath(@__DIR__, "output", "ag_scc")
mkpath(top_output_dir)

# Load all functions
include(joinpath(@__DIR__, "..", "src", "main.jl"))

# Settings
n = 1000
discount_rates = [
    (label = "1.5%", prtp = exp(9.149606e-05) - 1, eta = 1.016010e+00),
    (label = "2.0%", prtp = exp(0.001972641) - 1, eta = 1.244458999),
    (label = "2.5%", prtp = exp(0.004618784) - 1, eta = 1.421158088),
    (label = "3.0%", prtp = exp(0.007702711) - 1, eta = 1.567899391)
]

# Functions to remove agriculture uncertainty
function remove_ag_original(mcs)
    for coef in [1,2,3]
        for region in ["USA","CAN","WEU","JPK","ANZ","EEU","FSU","MDE","CAM","LAM","SAS","SEA","CHI","MAF","SSA","SIS"] # fund regions for ag
            rv_name = Symbol("rv_gtap_coef$(coef)_$region")
            Mimi.delete_RV!(mcs, rv_name)
        end
    end
end

function remove_ag_new(mcs)
    m = get_model()
    countries = dim_keys(m, :country)

    for coef in [1,2,3,4,5,6,7]
        for country in countries
            rv_name = Symbol("rv_gtap_coef$(coef)_$country")
            Mimi.delete_RV!(mcs, rv_name)
        end
    end
end

## -----------------------------------------------------------------------------
## SSP2 RCP45 | No Agriculture Uncertainty
## -----------------------------------------------------------------------------

SSP_scenarios = ["SSP245", "SSP585"]

for SSP_scenario in SSP_scenarios

    # Original
    output_dir = joinpath(top_output_dir, "$(SSP_scenario)_NoAgUncertainty", "original")
    mkpath(output_dir)

    m = MimiGIVE.get_model(; socioeconomics_source = :SSP, SSP_scenario = SSP_scenario)
    update_param!(m, :DamageAggregator, :include_slr, false)
    update_param!(m, :DamageAggregator, :include_cromar_mortality, false)
    update_param!(m, :DamageAggregator, :include_energy, false)

    save_list = [
                    (:DamageAggregator, :agriculture_damage),
                    (:temperature, :T),
                    # (:Agriculture, :temp),
                    # (:Agriculture, :AgLossGTAP)
                ]

    Random.seed!(seed)
    results = MimiGIVE.compute_scc(m;
                            year = 2020,
                            n = n,
                            discount_rates = discount_rates,
                            compute_sectoral_values = true,
                            post_mcs_creation_function = remove_ag_original,
                            output_dir = output_dir,
                            save_list = save_list
            )

    df = DataFrame()
    for (k,v) in results[:scc]
        append!(df, 
                DataFrame(
                    dr = k.dr_label,
                    sector = k.sector,
                    expected_scc = v.expected_scc .* pricelevel_2005_to_2020,
                    se_expected_scc = v.se_expected_scc .* pricelevel_2005_to_2020,
                    scc = v.sccs .* pricelevel_2005_to_2020,
                    trial = collect(1:n)
                )
            )
    end

    t = load(joinpath(output_dir, "results", "model_1", "temperature_T.csv")) |>
            @filter(_.time == 2100) |> 
            DataFrame

    df = innerjoin(df, select(t, Not(:time)), on = :trial => :trialnum)
    rename!(df, :T => :T_2100)
    df |> save(joinpath(output_dir, "scc.csv"))

    # New
    output_dir = joinpath(top_output_dir, "$(SSP_scenario)_NoAgUncertainty", "new")
    mkpath(output_dir)

    m = get_model(; socioeconomics_source = :SSP, SSP_scenario = SSP_scenario)
    update_param!(m, :DamageAggregator, :include_slr, false)
    update_param!(m, :DamageAggregator, :include_cromar_mortality, false)
    update_param!(m, :DamageAggregator, :include_energy, false)
    update_param!(m, :DamageAggregator, :include_labor, false)

    save_list = [
                    (:DamageAggregator, :agriculture_damage),
                    (:temperature, :T),
                    (:Agriculture, :agloss_gtap_frac)
                ]

    Random.seed!(seed)
    results = compute_scc(m;
                            year = 2020,
                            n = n,
                            discount_rates = discount_rates,
                            compute_sectoral_values = true,
                            post_mcs_creation_function = remove_ag_new,
                            output_dir = output_dir,
                            save_list = save_list
            )

    df = DataFrame()
    for (k,v) in results[:scc]
        append!(df, 
                DataFrame(
                    dr = k.dr_label,
                    sector = k.sector,
                    expected_scc = v.expected_scc .* pricelevel_2005_to_2020,
                    se_expected_scc = v.se_expected_scc .* pricelevel_2005_to_2020,
                    scc = v.sccs .* pricelevel_2005_to_2020,
                    trial = collect(1:n)
                )
            )
    end

    t = load(joinpath(output_dir, "results", "model_1", "temperature_T.csv")) |>
            @filter(_.time == 2100) |> 
            DataFrame

    df = innerjoin(df, select(t, Not(:time)), on = :trial => :trialnum)
    rename!(df, :T => :T_2100)
    df |> save(joinpath(output_dir, "scc.csv"))

    # Figure - SC-CO2
    df1 = load(joinpath(top_output_dir, "$(SSP_scenario)_NoAgUncertainty", "original", "scc.csv")) |> DataFrame
    insertcols!(df1, :version => :original)

    df2 = load(joinpath(top_output_dir, "$(SSP_scenario)_NoAgUncertainty", "new", "scc.csv")) |> DataFrame
    insertcols!(df2, :version => :new)

    df = vcat(df1, df2)
    original_exp_scc = round(unique((df |> @filter(_.dr == 0.02 && _.version == :original && _.sector == "total") |> DataFrame).expected_scc)[1], digits = 2)
    new_exp_scc = round(unique((df |> @filter(_.dr == 0.02 && _.version == :new && _.sector == "total") |> DataFrame).expected_scc)[1], digits = 2)

    df |>   @filter(_.dr == 0.02 && _.sector == "total") |>
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
                    text = {fontSize = 7},
                    title = {fontSize = 8, anchor = :start}
                },
                title = ["SC-CO2 | $(SSP_scenario) | No Ag Uncertainty", "Original E[SC-CO2] = $(original_exp_scc) | New E[SC-CO2] = $(new_exp_scc)"],
                mark = {:circle, size = 10, opacity = 0.6},
                x = {:T_2100, title = "GMST Anomaly Relative to 1750 (deg C)"},
                y = {:scc, title = "SC-CO2"},
                color = {:version, legend = {symbolOpacity = 1.}},
                row = {:version, title = nothing},
                resolve = {scale = {y = :independent}}
        ) |> save(joinpath(top_output_dir, "$(SSP_scenario)_NoAgUncertainty", "ag_scc_v1.png"), ppi = 300)

    # Figure - Temp
    df1 = load(joinpath(top_output_dir, "$(SSP_scenario)_NoAgUncertainty", "original", "results", "model_1", "temperature_T.csv")) |> DataFrame
    insertcols!(df1, :version => :original)

    df2 = load(joinpath(top_output_dir, "$(SSP_scenario)_NoAgUncertainty", "new", "results", "model_1", "temperature_T.csv")) |> DataFrame
    insertcols!(df2, :version => :new)

    df = vcat(df1, df2) |> @filter(_.time >= 2020) |> DataFrame

    df |> @vlplot(
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
                    text = {fontSize = 7},
                    title = {fontSize = 8, anchor = :start}
                },
                title = ["Temp | SSP2 RCP4.5 | No Ag Uncertainty", "Original E[SC-CO2] = $(original_exp_scc) | New E[SC-CO2] = $(new_exp_scc)"],
                mark = {:line, opacity = 0.4},
                x = {"time:q", title = "year"},
                y = {"T:q", title = "GMST Anomaly Relative to 1750 (deg C)"},
                strokeWidth = {"trialnum", scale = {range = [0.5]}, legend = false}, # hack to get lines to show up differently
                color = {:version, legend = {symbolOpacity = 1.}},
                width = 500
        ) |> save(joinpath(top_output_dir, "$(SSP_scenario)_NoAgUncertainty", "temperature.png"), ppi = 300)

    # # Figure - Ag Loss GTAP Fraction
    # df1 = load(joinpath(top_output_dir, "$(SSP_scenario)_NoAgUncertainty", "original", "results", "model_1", "Agriculture_AgLossGTAP.csv")) |> @filter(_.time >= 2020) |> DataFrame
    # rename!(df1, :AgLossGTAP => :loss_frac)
    # t = load(joinpath(top_output_dir, "$(SSP_scenario)_NoAgUncertainty", "original", "results", "model_1", "Agriculture_temp.csv")) |>
    #         @filter(_.time >= 2020) |>
    #         DataFrame
    # df1 = innerjoin(df1, t, on = [:time, :trialnum])

    # df2 = load(joinpath(top_output_dir, "$(SSP_scenario)_NoAgUncertainty", "new", "results", "model_1", "Agriculture_agloss_gtap_frac.csv")) |> @filter(_.time >= 2020) |> DataFrame
    # rename!(df2, :agloss_gtap_frac => :loss_frac)
    # t = load(joinpath(top_output_dir, "$(SSP_scenario)_NoAgUncertainty", "new", "results", "model_1", "temperature_T.csv")) |>
    #         @filter(_.time >= 2020) |>
    #         DataFrame
    # df2 = innerjoin(df2, t, on = [:time, :trialnum])

    # df1 |> @filter(_.fund_regions == "USA") |>
    #         @vlplot(
    #             config = {
    #                 font = "Helvetica",
    #                 # style = {cell = {stroke = :transparent}},
    #                 axis = {
    #                     labelFontSize = 7,
    #                     titleFontSize = 7,
    #                     domainColor = :black,
    #                     tickColor = :black,
    #                     titleFontWeight = :normal
    #                 },
    #                 legend = {
    #                     labelFontSize = 7,
    #                     titleFontSize = 7,
    #                     # orient = "bottom-right",
    #                     titleFontWeight = :normal,
    #                     symbolSize = 25.
    #                 },
    #                 text = {fontSize = 7},
    #                 title = {fontSize = 8, anchor = :start}
    #             },
    #             title = ["Original Model | Ag Loss Fraction | SSP2 RCP4.5 | No Ag Uncertainty"],
    #             mark = {:circle, size = 10, opacity = 0.7},
    #             x = {"temp:q", title = "GMST Anomaly Relative to 1995-2005 (deg C)"},
    #             y = {"loss_frac:q", title = "Agriculture Loss Fraction"},
    #             color = {"loss_frac:q", scale = {scheme = :viridis}, legend = {symbolOpacity = 1.}},
    #             height = 500,
    #             width = 500
    #     ) |> save(joinpath(top_output_dir, "$(SSP_scenario)_NoAgUncertainty", "loss_frac_original.png"), ppi = 300)

    # df2 |> @filter(_.country == "USA") |>
    #         @vlplot(
    #             config = {
    #                 font = "Helvetica",
    #                 # style = {cell = {stroke = :transparent}},
    #                 axis = {
    #                     labelFontSize = 7,
    #                     titleFontSize = 7,
    #                     domainColor = :black,
    #                     tickColor = :black,
    #                     titleFontWeight = :normal
    #                 },
    #                 legend = {
    #                     labelFontSize = 7,
    #                     titleFontSize = 7,
    #                     # orient = "bottom-right",
    #                     titleFontWeight = :normal,
    #                     symbolSize = 25.
    #                 },
    #                 text = {fontSize = 7},
    #                 title = {fontSize = 8, anchor = :start}
    #             },
    #             title = ["New Model | Ag Loss Fraction | SSP2 RCP4.5 | No Ag Uncertainty"],
    #             mark = {:circle, size = 10, opacity = 0.7},
    #             x = {"T:q", title = "GMST relative to 1750 (deg C)"},
    #             y = {"loss_frac:q", title = "Agriculture Loss Fraction"},
    #             color = {"loss_frac:q", scale = {scheme = :viridis}, legend = {symbolOpacity = 1.}},
    #             height = 500,
    #             width = 500
    #     ) |> save(joinpath(top_output_dir, "$(SSP_scenario)_NoAgUncertainty", "loss_frac_new.png"), ppi = 300)
end

## -----------------------------------------------------------------------------
## RFF SPs | No Agriculture Uncertainty
## -----------------------------------------------------------------------------

# Original

output_dir = joinpath(top_output_dir, "RFFSPs_NoAgUncertainty", "original")
mkpath(output_dir)

m = MimiGIVE.get_model()
update_param!(m, :DamageAggregator, :include_slr, false)
update_param!(m, :DamageAggregator, :include_cromar_mortality, false)
update_param!(m, :DamageAggregator, :include_energy, false)

save_list = [
                (:DamageAggregator, :agriculture_damage),
                (:temperature, :T),
                # (:Agriculture, :temp),
                # (:Agriculture, :AgLossGTAP)
            ]

Random.seed!(seed)
results = MimiGIVE.compute_scc(m;
                        year = 2020,
                        n = n,
                        discount_rates = discount_rates,
                        compute_sectoral_values = true,
                        post_mcs_creation_function = remove_ag_original,
                        output_dir = output_dir,
                        save_list = save_list
        )

df = DataFrame()
for (k,v) in results[:scc]
    append!(df, 
            DataFrame(
                dr = k.dr_label,
                sector = k.sector,
                expected_scc = v.expected_scc .* pricelevel_2005_to_2020,
                se_expected_scc = v.se_expected_scc .* pricelevel_2005_to_2020,
                scc = v.sccs .* pricelevel_2005_to_2020,
                trial = collect(1:n)
            )
        )
end

t = load(joinpath(output_dir, "results", "model_1", "temperature_T.csv")) |>
        @filter(_.time == 2100) |> 
        DataFrame

df = innerjoin(df, select(t, Not(:time)), on = :trial => :trialnum)
rename!(df, :T => :T_2100)
df |> save(joinpath(output_dir, "scc.csv"))

# New
output_dir = joinpath(top_output_dir, "RFFSPs_NoAgUncertainty", "new")
mkpath(output_dir)

m = get_model()
update_param!(m, :DamageAggregator, :include_slr, false)
update_param!(m, :DamageAggregator, :include_cromar_mortality, false)
update_param!(m, :DamageAggregator, :include_energy, false)
update_param!(m, :DamageAggregator, :include_labor, false)

save_list = [
                (:DamageAggregator, :agriculture_damage),
                (:temperature, :T),
                # (:Agriculture, :agloss_gtap_frac)
            ]

Random.seed!(seed)
results = compute_scc(m;
                        year = 2020,
                        n = n,
                        discount_rates = discount_rates,
                        compute_sectoral_values = true,
                        post_mcs_creation_function = remove_ag_new,
                        output_dir = output_dir,
                        save_list = save_list
        )

df = DataFrame()
for (k,v) in results[:scc]
    append!(df, 
            DataFrame(
                dr = k.dr_label,
                sector = k.sector,
                expected_scc = v.expected_scc .* pricelevel_2005_to_2020,
                se_expected_scc = v.se_expected_scc .* pricelevel_2005_to_2020,
                scc = v.sccs .* pricelevel_2005_to_2020,
                trial = collect(1:n)
            )
        )
end

t = load(joinpath(output_dir, "results", "model_1", "temperature_T.csv")) |>
        @filter(_.time == 2100) |> 
        DataFrame

df = innerjoin(df, select(t, Not(:time)), on = :trial => :trialnum)
rename!(df, :T => :T_2100)
df |> save(joinpath(output_dir, "scc.csv"))

# Figure - SC-CO2
df1 = load(joinpath(top_output_dir, "RFFSPs_NoAgUncertainty", "original", "scc.csv")) |> DataFrame
insertcols!(df1, :version => :original)

df2 = load(joinpath(top_output_dir, "RFFSPs_NoAgUncertainty", "new", "scc.csv")) |> DataFrame
insertcols!(df2, :version => :new)

df = vcat(df1, df2)
original_exp_scc = round(unique((df |> @filter(_.dr == 0.02 && _.version == :original && _.sector == "total") |> DataFrame).expected_scc)[1], digits = 2)
new_exp_scc = round(unique((df |> @filter(_.dr == 0.02 && _.version == :new && _.sector == "total") |> DataFrame).expected_scc)[1], digits = 2)

df |>   @filter(_.dr == 0.02 && _.sector == "total") |>
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
                text = {fontSize = 7},
                title = {fontSize = 8, anchor = :start}
            },
            title = ["SC-CO2 | RFFSPs | No Ag Uncertainty", "Original E[SC-CO2] = $(original_exp_scc) | New E[SC-CO2] = $(new_exp_scc)"],
            mark = {:circle, size = 10, opacity = 0.6},
            x = {:T_2100, title = "GMST Anomaly Relative to 1750 (deg C)"},
            y = {:scc, title = "SC-CO2"},
            color = {:version, legend = {symbolOpacity = 1.}},
            row = {:version, title = nothing},
            resolve = {scale = {y = :independent}}
    ) |> save(joinpath(top_output_dir, "RFFSPs_NoAgUncertainty", "ag_scc_v1.png"), ppi = 300)

# Figure - Temp
df1 = load(joinpath(top_output_dir, "RFFSPs_NoAgUncertainty", "original", "results", "model_1", "temperature_T.csv")) |> DataFrame
insertcols!(df1, :version => :original)

df2 = load(joinpath(top_output_dir, "RFFSPs_NoAgUncertainty", "new", "results", "model_1", "temperature_T.csv")) |> DataFrame
insertcols!(df2, :version => :new)

df = vcat(df1, df2) |> @filter(_.time >= 2020) |> DataFrame

df |> @vlplot(
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
                text = {fontSize = 7},
                title = {fontSize = 8, anchor = :start}
            },
            title = ["Temp | RFFSPs | No Ag Uncertainty", "Original E[SC-CO2] = $(original_exp_scc) | New E[SC-CO2] = $(new_exp_scc)"],
            mark = {:line, opacity = 0.4},
            x = {"time:q", title = "year"},
            y = {"T:q", title = "GMST Anomaly Relative to 1750 (deg C)"},
            strokeWidth = {"trialnum", scale = {range = [0.5]}, legend = false}, # hack to get lines to show up differently
            color = {:version, legend = {symbolOpacity = 1.}},
            width = 500
    ) |> save(joinpath(top_output_dir, "RFFSPs_NoAgUncertainty", "temperature.png"), ppi = 300)

## -----------------------------------------------------------------------------
## RFF SPs | Full Uncertainty
## -----------------------------------------------------------------------------

# Original

output_dir = joinpath(top_output_dir, "RFFSPs_FullUncertainty", "original")
mkpath(output_dir)

m = MimiGIVE.get_model()
update_param!(m, :DamageAggregator, :include_slr, false)
update_param!(m, :DamageAggregator, :include_cromar_mortality, false)
update_param!(m, :DamageAggregator, :include_energy, false)

save_list = [
                (:DamageAggregator, :agriculture_damage),
                (:temperature, :T),
                # (:Agriculture, :temp),
                # (:Agriculture, :AgLossGTAP)
            ]

Random.seed!(seed)
results = MimiGIVE.compute_scc(m;
                        year = 2020,
                        n = n,
                        discount_rates = discount_rates,
                        compute_sectoral_values = true,
                        output_dir = output_dir,
                        save_list = save_list
        )

df = DataFrame()
for (k,v) in results[:scc]
    append!(df, 
            DataFrame(
                dr = k.dr_label,
                sector = k.sector,
                expected_scc = v.expected_scc .* pricelevel_2005_to_2020,
                se_expected_scc = v.se_expected_scc .* pricelevel_2005_to_2020,
                scc = v.sccs .* pricelevel_2005_to_2020,
                trial = collect(1:n)
            )
        )
end

t = load(joinpath(output_dir, "results", "model_1", "temperature_T.csv")) |>
        @filter(_.time == 2100) |> 
        DataFrame

df = innerjoin(df, select(t, Not(:time)), on = :trial => :trialnum)
rename!(df, :T => :T_2100)
df |> save(joinpath(output_dir, "scc.csv"))

# New
output_dir = joinpath(top_output_dir, "RFFSPs_FullUncertainty", "new")
mkpath(output_dir)

m = get_model()
update_param!(m, :DamageAggregator, :include_slr, false)
update_param!(m, :DamageAggregator, :include_cromar_mortality, false)
update_param!(m, :DamageAggregator, :include_energy, false)
update_param!(m, :DamageAggregator, :include_labor, false)

save_list = [
                (:DamageAggregator, :agriculture_damage),
                (:temperature, :T),
                # (:Agriculture, :agloss_gtap_frac)
            ]

Random.seed!(seed)
results = compute_scc(m;
                        year = 2020,
                        n = n,
                        discount_rates = discount_rates,
                        compute_sectoral_values = true,
                        output_dir = output_dir,
                        save_list = save_list
        )

df = DataFrame()
for (k,v) in results[:scc]
    append!(df, 
            DataFrame(
                dr = k.dr_label,
                sector = k.sector,
                expected_scc = v.expected_scc .* pricelevel_2005_to_2020,
                se_expected_scc = v.se_expected_scc .* pricelevel_2005_to_2020,
                scc = v.sccs .* pricelevel_2005_to_2020,
                trial = collect(1:n)
            )
        )
end

t = load(joinpath(output_dir, "results", "model_1", "temperature_T.csv")) |>
        @filter(_.time == 2100) |> 
        DataFrame

df = innerjoin(df, select(t, Not(:time)), on = :trial => :trialnum)
rename!(df, :T => :T_2100)
df |> save(joinpath(output_dir, "scc.csv"))

# Figure - SC-CO2
df1 = load(joinpath(top_output_dir, "RFFSPs_FullUncertainty", "original", "scc.csv")) |> DataFrame
insertcols!(df1, :version => :original)

df2 = load(joinpath(top_output_dir, "RFFSPs_FullUncertainty", "new", "scc.csv")) |> DataFrame
insertcols!(df2, :version => :new)

df = vcat(df1, df2)
original_exp_scc = round(unique((df |> @filter(_.dr == 0.02 && _.version == :original && _.sector == "total") |> DataFrame).expected_scc)[1], digits = 2)
new_exp_scc = round(unique((df |> @filter(_.dr == 0.02 && _.version == :new && _.sector == "total") |> DataFrame).expected_scc)[1], digits = 2)

df |>   @filter(_.dr == 0.02 && _.sector == "total") |>
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
                text = {fontSize = 7},
                title = {fontSize = 8, anchor = :start}
            },
            title = ["SC-CO2 | RFFSPs | Full Uncertainty", "Original E[SC-CO2] = $(original_exp_scc) | New E[SC-CO2] = $(new_exp_scc)"],
            mark = {:circle, size = 10, opacity = 0.6},
            x = {:T_2100, title = "GMST Anomaly Relative to 1750 (deg C)"},
            y = {:scc, title = "SC-CO2"},
            color = {:version, legend = {symbolOpacity = 1.}},
            row = :version,
            resolve = {scale = {y = :independent}}
    ) |> save(joinpath(top_output_dir, "RFFSPs_FullUncertainty", "ag_scc.png"), ppi = 300)

# Figure - Temp
df1 = load(joinpath(top_output_dir, "RFFSPs_FullUncertainty", "original", "results", "model_1", "temperature_T.csv")) |> DataFrame
insertcols!(df1, :version => :original)

df2 = load(joinpath(top_output_dir, "RFFSPs_FullUncertainty", "new", "results", "model_1", "temperature_T.csv")) |> DataFrame
insertcols!(df2, :version => :new)

df = vcat(df1, df2) |> @filter(_.time >= 2020) |> DataFrame

df |> @vlplot(
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
                text = {fontSize = 7},
                title = {fontSize = 8, anchor = :start}
            },
            title = ["Temp | RFFSPs | Full Uncertainty", "Original E[SC-CO2] = $(original_exp_scc) | New E[SC-CO2] = $(new_exp_scc)"],
            mark = {:line, opacity = 0.4},
            x = {"time:q", title = "year"},
            y = {"T:q", title = "GMST Anomaly Relative to 1750 (deg C)"},
            strokeWidth = {"trialnum", scale = {range = [0.5]}, legend = false}, # hack to get lines to show up differently
            color = {:version, legend = {symbolOpacity = 1.}},
            width = 500
    ) |> save(joinpath(top_output_dir, "RFFSPs_FullUncertainty", "temperature.png"), ppi = 300)
