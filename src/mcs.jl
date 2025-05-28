using Mimi
using MimiGIVE
using Distributions
using Dates

"""
    get_mcs(trials; 
            socioeconomics_source::Symbol = :RFF, 
            mcs_years = 1750:2300, 
            fair_parameter_set::Symbol = :random,
            fair_parameter_set_ids::Union{Vector{Int}, Nothing} = nothing,
            rffsp_sampling::Symbol = :random,
            rffsp_sampling_ids::Union{Vector{Int}, Nothing} = nothing,
            save_list::Vector = []
        )

Return a Monte Carlo Simulation definition of type Mimi.SimulationDefinition that
holds all random variables and distributions, as assigned to model component/parameter
pairs, that will be used in a Monte Carlo Simulation. 

- `trials` (required) - number of trials to be run, used for presampling
- `socioeconomics_source` (default :RFF) - which source the Socioeconomics component uses
- `fair_parameter_set` (default :random) - :random means FAIR mcs samples will be 
        chosen randomly from the provided sets, while :deterministic means they will 
        be  based on the provided vector of to `fair_parameter_set_ids` keyword argument. 
- `fair_parameter_set_ids` (default nothing) - if `fair_parameter_set` is set 
        to :deterministic, this `n` element vector provides the fair parameter set ids 
        that will be run, otherwise it is set to `nothing` and ignored.
- `rffsp_sampling` (default :random) - which sampling strategy to use for the RFF 
        SPs, :random means RFF SPs will be chosen randomly, while :deterministic means they 
        will be based on the provided vector of to `rffsp_sampling_ids` keyword argument. 
- `rffsp_sampling_ids` (default nothing) - if `rffsp_sampling` is set to :deterministic, 
        this `n` element vector provides the RFF SP ids that will be run, otherwise it is 
        set to `nothing` and ignored.
- `save_list` (default []) - which parameters and varaibles to save for each trial,
        entered as a vector of Tuples (:component_name, :variable_name)
"""
function get_mcs(trials; 
            socioeconomics_source::Symbol = :RFF, 
            mcs_years = 1750:2300, 
            fair_parameter_set::Symbol = :random,
            fair_parameter_set_ids::Union{Vector{Int}, Nothing} = nothing,
            rffsp_sampling::Symbol = :random,
            rffsp_sampling_ids::Union{Vector{Int}, Nothing} = nothing,
            save_list::Vector = []
        )

    # get the original MCS
    mcs = MimiGIVE.get_mcs(trials;
                            socioeconomics_source = socioeconomics_source, 
                            mcs_years = mcs_years, 
                            fair_parameter_set = fair_parameter_set, 
                            fair_parameter_set_ids = fair_parameter_set_ids,
                            rffsp_sampling = rffsp_sampling,
                            rffsp_sampling_ids = rffsp_sampling_ids,
                            save_list = save_list,
                        )

    # remove old agriculure component random variables
    for coef in [1,2,3] # three coefficients defined with an anonymous dimension
        for region in ["USA","CAN","WEU","JPK","ANZ","EEU","FSU","MDE","CAM","LAM","SAS","SEA","CHI","MAF","SSA","SIS"] # fund regions for ag
            rv_name = Symbol("rv_gtap_coef$(coef)_$region")
            Mimi.delete_RV!(mcs, rv_name)
        end
    end

    # add uncertainty for labor GCM
    gcm_options = collect(2:size(load(joinpath(@__DIR__, "..", "data", "dimension_gcm.csv")) |> DataFrame, 1)) # 1 is the ensemble
    rv_name = :labor_gcm
    Mimi.add_RV!(mcs, rv_name, Mimi.EmpiricalDistribution(gcm_options)) # add random variable 
    Mimi.add_transform!(mcs, :Labor, :gcm, :(=), rv_name) # connect random variable to parameter

    # add uncertainty for agriculture
    filepath = joinpath(@__DIR__, "..", "data", "gtap_output/202505_Plants_People_v2.csv")
    countries, ag_sample_stores = get_probdists_gtap_df(filepath, trials)
 
    for coef in [1,2,3,4,5,6,7] # seven coefficients defined with an anonymous dimension
        for (i, country) in enumerate(countries)
            rv_name = Symbol("rv_gtap_coef$(coef)_$country")
            Mimi.add_RV!(mcs, rv_name, ag_sample_stores[i, coef])
            Mimi.add_transform!(mcs, :Agriculture, :gtap_impacts, :(=), rv_name, [country, coef])
        end
    end
    return mcs
end

function run_mcs(;trials::Int64 = 10000, 
                            output_dir::Union{String, Nothing} = nothing, 
                            save_trials::Bool = false,
                            fair_parameter_set::Symbol = :random,
                            fair_parameter_set_ids::Union{Vector{Int}, Nothing} = nothing,
                            rffsp_sampling::Symbol = :random,
                            rffsp_sampling_ids::Union{Vector{Int}, Nothing} = nothing,
                            m::Mimi.Model = get_model(), # <-- using a different default model
                            save_list::Vector = [],
                            results_in_memory::Bool = true,
                        )

    m = deepcopy(m) # in the case that an `m` was provided, be careful that we don't modify the original

    trials < 2 && error("Must run `run_mcs` function with a `trials` argument greater than 1 due to a Mimi specification about SampleStores.  TO BE FIXED SOON!")

    # Set up output directories
    output_dir = output_dir === nothing ? joinpath(@__DIR__, "../output/mcs/", "mcs_n$trials") : output_dir
    isdir("$output_dir/results") || mkpath("$output_dir/results")

    trials_output_filename = save_trials ?  joinpath("$output_dir/trials.csv") : nothing

    socioeconomics_module = MimiGIVE._get_module_name(m, :Socioeconomic)
    if socioeconomics_module == :MimiSSPs
        socioeconomics_source = :SSP
    elseif socioeconomics_module == :MimiRFFSPs
        socioeconomics_source = :RFF
    end

    # Get an instance of the mcs
    mcs = get_mcs(trials;  # <-- using a different function to obtain the mcs
        socioeconomics_source = socioeconomics_source, 
        mcs_years = Mimi.time_labels(m), 
        fair_parameter_set = fair_parameter_set, 
        fair_parameter_set_ids = fair_parameter_set_ids,
        rffsp_sampling = rffsp_sampling,
        rffsp_sampling_ids = rffsp_sampling_ids,
        save_list = save_list,
    )

    # run monte carlo trials
    results = run(mcs,
        m, 
        trials; 
        trials_output_filename = trials_output_filename, 
        results_output_dir = "$output_dir/results", 
        results_in_memory = results_in_memory
    )

    return results
end
