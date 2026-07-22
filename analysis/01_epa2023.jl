using Mimi, MimiGIVE, Random, CSVFiles, DataFrames, Statistics

# paths
epa2023_output_dir = joinpath(@__DIR__, "../output/epa2023")
mkpath(epa2023_output_dir)

# set emissions year
year = 2025;

# choose damage module
damages = :give;

# choose gas
gas = :CO2;

# set named list of discount rates
epa_discount_rates = 
    [
        (label = "1.5% Ramsey", prtp = exp(0.000091496)-1, eta  = 1.016010261),
        (label = "2.0% Ramsey", prtp = exp(0.001972641)-1, eta  = 1.244459020),
        (label = "2.5% Ramsey", prtp = exp(0.004618785)-1, eta  = 1.421158057)
    ]

# read the series of randomly selected rffsp-fair pairings used to generate the
# scghg distribution for the epa 2023 analysis
rffsp_fair_sequence = load(joinpath(@__DIR__, "../data/epa2023/rffsp_fair_sequence.csv")) |> DataFrame
fair_parameter_set_ids = (rffsp_fair_sequence.fair_id)[1:num_trials]
rffsp_sampling_ids     = (rffsp_fair_sequence.rffsp_id)[1:num_trials]

# set random seed
Random.seed!(seed)

# get model 
m = MimiGIVE.get_model()

# estimate scghg
results = 
    MimiGIVE.compute_scc(m, 
                        n                       = num_trials, 
                        gas                     = gas, 
                        year                    = year, 
                        pulse_size              = 0.0001,                   # scales the default pulse size of 1Gt to 100k metric tons 
                        certainty_equivalent    = false,                     
                        fair_parameter_set      = :deterministic,           # optionally read the rffsp-fair parameter sequence from file
                        fair_parameter_set_ids  = fair_parameter_set_ids,   # optionally read the rffsp-fair parameter sequence from file
                        rffsp_sampling          = :deterministic,           # optionally read the rffsp-fair parameter sequence from file
                        rffsp_sampling_ids      = rffsp_sampling_ids,       # optionally read the rffsp-fair parameter sequence from file
                        CIAM_GDPcap             = true, 
                        discount_rates          = epa_discount_rates, 
                        save_slr_damages        = false,                    # save coastal damages, comparable to including DamageAggregator components in save_list
                        save_cpc                = false,                    # must be true to recover certainty equivalent scghgs
                        compute_domestic_values = false,
                        compute_sectoral_values = true)

# blank data
scghgs = DataFrame(sector = String[], discount_rate = String[], trial = Int[], scghg = Float64[])
    
# populate data
for (k, v) in results[:scc]
    for (i, sc) in enumerate(v.sccs)
        push!(scghgs, (sector = String(k.sector), discount_rate = k.dr_label, trial = i, scghg = sc*pricelevel_2005_to_2020))
    end
end

# export full distribution    
scghgs |> save(joinpath(epa2023_output_dir, "sc-$gas-$damages-$year-n$num_trials.csv"))

# collapse to the certainty equivalent scghgs
scghgs_mean = combine(groupby(scghgs, [:sector, :discount_rate]), :scghg => (x -> round(Int, mean(x))) .=> :scghg)

# export average scghgs    
scghgs_mean |> save(joinpath(epa2023_output_dir, "sc-$gas-$damages-$year.csv"))
