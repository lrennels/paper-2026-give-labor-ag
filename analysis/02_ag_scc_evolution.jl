using Mimi, VegaLite, Random, Query, DataFrames

output_dir = joinpath(@__DIR__, "..", "output", "ag_scc_evolution", "pulse$(year)_n$(num_trials)_seed$(seed)")
mkpath(output_dir)

# Year
year = 2020

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

# Original

m = MimiGIVE.get_model(; socioeconomics_source = :SSP, SSP_scenario = "SSP245")
update_param!(m, :DamageAggregator, :include_slr, false)
update_param!(m, :DamageAggregator, :include_cromar_mortality, false)
update_param!(m, :DamageAggregator, :include_energy, false)

Random.seed!(seed)
results = MimiGIVE.compute_scc(m;
                        year = 2020,
                        n = num_trials,
                        discount_rates = discount_rates,
                        compute_sectoral_values = true,
                        post_mcs_creation_function = remove_ag_original,
                        output_dir = output_dir,
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
                trial = collect(1:num_trials)
            )
        )
end

df |> @filter(_.sector == :agriculture) |> save(joinpath(output_dir, "SSP245_NoAgUncertainty_original_ag_scc.csv"))

# New

m = get_model(; socioeconomics_source = :SSP, SSP_scenario = "SSP245")
update_param!(m, :DamageAggregator, :include_slr, false)
update_param!(m, :DamageAggregator, :include_cromar_mortality, false)
update_param!(m, :DamageAggregator, :include_energy, false)
update_param!(m, :DamageAggregator, :include_labor, false)

Random.seed!(seed)
results = compute_scc(m;
                        year = 2020,
                        n = num_trials,
                        discount_rates = discount_rates,
                        compute_sectoral_values = true,
                        post_mcs_creation_function = remove_ag_new,
                        output_dir = output_dir,
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
                trial = collect(1:num_trials)
            )
        )
end

df |> @filter(_.sector == :agriculture) |> save(joinpath(output_dir, "SSP245_NoAgUncertainty_new_ag_scc.csv"))

## -----------------------------------------------------------------------------
## RFF SPs | No Agriculture Uncertainty
## -----------------------------------------------------------------------------

# Original

m = MimiGIVE.get_model()
update_param!(m, :DamageAggregator, :include_slr, false)
update_param!(m, :DamageAggregator, :include_cromar_mortality, false)
update_param!(m, :DamageAggregator, :include_energy, false)

Random.seed!(seed)
results = MimiGIVE.compute_scc(m;
                        year = 2020,
                        n = num_trials,
                        discount_rates = discount_rates,
                        compute_sectoral_values = true,
                        post_mcs_creation_function = remove_ag_original,
                        output_dir = output_dir,
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
                trial = collect(1:num_trials)
            )
        )
end

df |> @filter(_.sector == :agriculture) |> save(joinpath(output_dir, "RFFSPs_NoAgUncertainty_original_ag_scc.csv"))

# New

m = get_model()
update_param!(m, :DamageAggregator, :include_slr, false)
update_param!(m, :DamageAggregator, :include_cromar_mortality, false)
update_param!(m, :DamageAggregator, :include_energy, false)
update_param!(m, :DamageAggregator, :include_labor, false)

Random.seed!(seed)
results = compute_scc(m;
                        year = 2020,
                        n = num_trials,
                        discount_rates = discount_rates,
                        compute_sectoral_values = true,
                        post_mcs_creation_function = remove_ag_new,
                        output_dir = output_dir,
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
                trial = collect(1:num_trials)
            )
        )
end

df |> @filter(_.sector == :agriculture) |> save(joinpath(output_dir, "RFFSPs_NoAgUncertainty_new_ag_scc.csv"))

## -----------------------------------------------------------------------------
## RFF SPs | Full Uncertainty
## -----------------------------------------------------------------------------

# Original

m = MimiGIVE.get_model()
update_param!(m, :DamageAggregator, :include_slr, false)
update_param!(m, :DamageAggregator, :include_cromar_mortality, false)
update_param!(m, :DamageAggregator, :include_energy, false)

Random.seed!(seed)
results = MimiGIVE.compute_scc(m;
                        year = 2020,
                        n = num_trials,
                        discount_rates = discount_rates,
                        compute_sectoral_values = true,
                        output_dir = output_dir,
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
                trial = collect(1:num_trials)
            )
        )
end

df |> @filter(_.sector == :agriculture) |> save(joinpath(output_dir, "RFFSPs_FullUncertainty_original_ag_scc.csv"))

# New

m = get_model()
update_param!(m, :DamageAggregator, :include_slr, false)
update_param!(m, :DamageAggregator, :include_cromar_mortality, false)
update_param!(m, :DamageAggregator, :include_energy, false)
update_param!(m, :DamageAggregator, :include_labor, false)

Random.seed!(seed)
results = compute_scc(m;
                        year = 2020,
                        n = num_trials,
                        discount_rates = discount_rates,
                        compute_sectoral_values = true,
                        output_dir = output_dir,
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
                trial = collect(1:num_trials)
            )
        )
end

df |> @filter(_.sector == :agriculture) |> save(joinpath(output_dir, "RFFSPs_FullUncertainty_new_ag_scc.csv"))

## -----------------------------------------------------------------------------
## SCC Distribution Graphs
## -----------------------------------------------------------------------------

df = DataFrame()

i = 1
for category in ["SSP245_NoAgUncertainty", "RFFSPs_NoAgUncertainty", "RFFSPs_FullUncertainty"], version in ["original", "new"]

    filename = joinpath(output_dir, "$(category)_$(version)_ag_scc.csv")
    df_quantiles = load(filename) |>
                        @mutate(sector = _.sector == "agriculture" ? "Agriculture" : "") |>
                        @groupby({_.dr, _.sector}) |>
                        @map({key(_)..., q05 = quantile(_.scc, 0.05), q25 = quantile(_.scc, 0.25), median = quantile(_.scc, 0.5), q75 = quantile(_.scc, 0.75), q95 = quantile(_.scc, 0.95), mean = mean(_.scc)}) |>
                        DataFrame
    insertcols!(df_quantiles, :category => category)
    insertcols!(df_quantiles, :version => version)
    insertcols!(df_quantiles, :label => "$(category) $(version)")
    append!(df, df_quantiles)
end

df |> save(joinpath(output_dir, "scc_evolution_quantile_summary.csv"))

for dr in unique(df.dr)
df |>   @filter(_.dr == dr) |>
        @vlplot(  
                        y = {"label:n", axis = {domain = false, ticks = false, title = nothing, grid = false}, sort = "descending"},
                        # color = {"version:n", legend = nothing, scale = {range = ["#758aad", "#bfa468", "#7fa89f", "#b38f8d", "#7a946c", "#7B5EA6"]}},
                        color = {"version:n", scale = {range = ["#758aad", "#bfa468", "#7fa89f", "#b38f8d", "#7a946c", "#7B5EA6"]}},
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
                            step = 24
                        }) +
                    @vlplot(:rule, x = {
                            "q05:q",
                            axis = {title = "SC-CO₂ (US\$ per tonne of CO₂) (n = 1000)", grid = true}
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
            ) |> save(joinpath(output_dir, "scc_evolution_dr$(dr).png"), ppi = 300)
end

