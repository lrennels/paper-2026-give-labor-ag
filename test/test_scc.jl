using Mimi, VegaLite

output_dir = joinpath(@__DIR__, "output", "scc")
mkpath(output_dir)

# Load all functions
include(joinpath(@__DIR__, "..", "src", "main.jl"))

# Settings
num_trials = 100
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

# Deterministic SCC
m = get_model()
scc = compute_scc(m, year = 2020)

m = get_model(; socioeconomics_source = :SSP, SSP_scenario = "SSP245")
scc = compute_scc(m, year = 2020)

m = get_model(; socioeconomics_source = :SSP, SSP_scenario = "SSP585")
scc = compute_scc(m, year = 2020)

# TODO SSP ordering magnitude looks off

# Monte Carlo SCC
m = get_model()
update_param!(m, :DamageAggregator, :include_slr, false)
results = compute_scc(m;
                        year = 2020,
                        n = num_trials,
                        output_dir = output_dir,
                        save_list = save_list,
                        discount_rates = discount_rates,
                        compute_sectoral_values = true,
                        save_md = true
        )

# TODO the ag sector seems too low
df = DataFrame()
for (k,v) in results[:scc]
    append!(df, 
                DataFrame(
                    dr = k.dr_label,
                    sector = k.sector,
                    expected_scc = v.expected_scc,
                    se_expected_scc = v.se_expected_scc
                )
            )
end

df |> @vlplot(
                :bar,
                x = :dr,
                y = :expected_scc,
                color = :sector
            ) |> save(joinpath(output_dir, "scc.png"), ppi = 300)

df = DataFrame()
for (k,v) in results[:mds]
    vals = DataFrame(v, string.(collect(2020:2300)))
    insertcols!(vals, 1, :trial => collect(1:num_trials))
    vals = stack(vals, Not(:trial))
    insertcols!(vals, 1, :sector => k.sector)
    vals.variable = parse.(Int64, vals.variable)
    append!(df, vals)
end

df |> 
    @filter(_.variable <= 2100) |>
    @vlplot(
                resolve = {scale = {y = :independent}},
                :line,
                x = :variable,
                y = :value,
                color = :sector,
                strokeWidth = {"trial", scale = {range = [0.5]}, legend = false}, # hack to get lines to show up differently
                width = 150,
                height = 150,
                wrap = :sector,
                columns = 3
            ) |> save(joinpath(output_dir, "mds.png"), ppi = 300)

