using Mimi, MimiGIVE

output_dir = joinpath(@__DIR__, "output", "ag_scc")
mkpath(output_dir)

# Load all functions
include(joinpath(@__DIR__, "..", "src", "main.jl"))

# DETERMINISTIC

m = MimiGIVE.get_model(; socioeconomics_source = :SSP, SSP_scenario = "SSP245")
update_param!(m, :DamageAggregator, :include_slr, false)
update_param!(m, :DamageAggregator, :include_cromar_mortality, false)
update_param!(m, :DamageAggregator, :include_energy, false)
results_give = MimiGIVE.compute_scc(m;
                        year = 2020,
                        prtp = exp(9.149606e-05) - 1,
                        eta = 1.016010e+00,
                        compute_sectoral_values = true
        )

println("Deterministic run of SSP245 GIVE version = $(results_give)")
# Deterministic run of SSP245 GIVE version = 63.30369956855238

m = get_model(; socioeconomics_source = :SSP, SSP_scenario = "SSP245")
update_param!(m, :DamageAggregator, :include_slr, false)
update_param!(m, :DamageAggregator, :include_cromar_mortality, false)
update_param!(m, :DamageAggregator, :include_energy, false)
update_param!(m, :DamageAggregator, :include_labor, false)

results_new = compute_scc(m;
                        year = 2020,
                        prtp = exp(9.149606e-05) - 1,
                        eta = 1.016010e+00,
                        compute_sectoral_values = true
        )
    
println("Deterministic run of SSP245 NEW version = $(results_new)")
# Deterministic run of SSP245 NEW version = 3.3525169646280046

# MCS

# settings
num_trials = 10_000
discount_rates = [
    (label = "1.5%", prtp = exp(9.149606e-05) - 1, eta = 1.016010e+00),
    (label = "2.0%", prtp = exp(0.001972641) - 1, eta = 1.244458999),
    (label = "2.5%", prtp = exp(0.004618784) - 1, eta = 1.421158088),
    (label = "3.0%", prtp = exp(0.007702711) - 1, eta = 1.567899391)
]

# Original MimiGIVE

m = MimiGIVE.get_model()
update_param!(m, :DamageAggregator, :include_slr, false)

function remove_ag(mcs)
    for coef in [1,2,3]
        for region in ["USA","CAN","WEU","JPK","ANZ","EEU","FSU","MDE","CAM","LAM","SAS","SEA","CHI","MAF","SSA","SIS"] # fund regions for ag
            rv_name = Symbol("rv_gtap_coef$(coef)_$region")
            Mimi.delete_RV!(mcs, rv_name)
        end
    end
end

results_ag_give = MimiGIVE.compute_scc(m;
                        year = 2020,
                        n = num_trials,
                        discount_rates = discount_rates,
                        compute_sectoral_values = true,
                        post_mcs_creation_function = remove_ag
        )

df_ag_give = DataFrame()
for (k,v) in results_ag_give[:scc]
    append!(df_ag_give, 
                DataFrame(
                    dr = k.dr_label,
                    sector = k.sector,
                    expected_scc = v.expected_scc .* pricelevel_2005_to_2020,
                    se_expected_scc = v.se_expected_scc .* pricelevel_2005_to_2020
                )
            )
end

# without ag MCS

#  Row │ dr      sector       expected_scc  se_expected_scc 
#      │ String  Symbol       Float64       Float64         
# ─────┼────────────────────────────────────────────────────
#    1 │ 2.0%    agriculture       69.5603          25.0335
#    2 │ 1.5%    agriculture      129.525           43.674
#    3 │ 2.5%    agriculture       42.2579          16.3797
#    4 │ 3.0%    agriculture       28.2304          11.8726

# with ag MCS

#  Row │ dr      sector       expected_scc  se_expected_scc 
#      │ String  Symbol       Float64       Float64         
# ─────┼────────────────────────────────────────────────────
#    1 │ 2.0%    agriculture       81.5173          2.97001
#    2 │ 1.5%    agriculture      130.631           4.16798
#    3 │ 2.5%    agriculture       52.3352          2.15958
#    4 │ 3.0%    agriculture       34.8274          1.60303

# New Model

m = get_model()
update_param!(m, :DamageAggregator, :include_slr, false)

function remove_ag(mcs)
    m = get_model()
    countries = dim_keys(m, :country)

    for coef in [1,2,3,4,5,6,7]
        for country in countries
            rv_name = Symbol("rv_gtap_coef$(coef)_$country")
            Mimi.delete_RV!(mcs, rv_name)
        end
    end
end

results_ag_new = compute_scc(m;
                        year = 2020,
                        n = num_trials,
                        discount_rates = discount_rates,
                        compute_sectoral_values = true,
                        post_mcs_creation_function = remove_ag
        )

df_ag_new = DataFrame()
for (k,v) in results_ag_new[:scc]
    append!(df_ag_new, 
                DataFrame(
                    dr = k.dr_label,
                    sector = k.sector,
                    expected_scc = v.expected_scc .* pricelevel_2005_to_2020,
                    se_expected_scc = v.se_expected_scc .* pricelevel_2005_to_2020
                )
            )
end

