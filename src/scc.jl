using Dates, CSVFiles, DataFrames, Mimi, Query

# import constants from MimiGIVE
import MimiGIVE: _model_years, _damages_years, _damages_idxs, scc_gas_molecular_conversions, scc_gas_pulse_size_conversions

# Primary compute scc function
function compute_scc(m::Model = get_model(); 
            year::Union{Int, Nothing} = nothing, 
            last_year::Int = _model_years[end], 
            prtp::Union{Float64,Nothing} = 0.015, 
            eta::Union{Float64,Nothing} = 1.45,
            discount_rates = nothing,
            certainty_equivalent = false,
            fair_parameter_set::Symbol = :random,
            fair_parameter_set_ids::Union{Vector{Int}, Nothing} = nothing,
            rffsp_sampling::Symbol = :random,
            rffsp_sampling_ids::Union{Vector{Int}, Nothing} = nothing,
            n = 0,
            gas::Symbol = :CO2,
            save_list::Vector = [],
            output_dir::Union{String, Nothing} = nothing,
            save_md::Bool = false,
            save_cpc::Bool = false,
            compute_sectoral_values::Bool = false,
            CIAM_foresight::Symbol = :perfect,
            CIAM_GDPcap::Bool = false,
            post_mcs_creation_function = nothing,
            pulse_size::Float64 = 1.,
            compute_labor_country_sccs::Bool = false
        )

    hfc_list = [:HFC23, :HFC32, :HFC43_10, :HFC125, :HFC134a, :HFC143a, :HFC227ea, :HFC245fa]
    gases_list = [:CO2, :CH4, :N2O, hfc_list ...]

    m = deepcopy(m) # in the case that an `m` was provided, be careful that we don't modify the original

    year === nothing ? error("Must specify an emission year. Try `compute_scc(m, year=2020)`.") : nothing
    !(last_year in _model_years) ? error("Invalid value of $last_year for last_year. last_year must be within the model's time index $_model_years.") : nothing
    !(year in _model_years) ? error("Cannot compute the scc for year $year, year must be within the model's time index $_model_years.") : nothing
    !(gas in gases_list) ? error("Invalid value of $gas for gas, gas must be one of $(gases_list).") : nothing

    mm = MimiGIVE.get_marginal_model(m; year = year, gas = gas, pulse_size = pulse_size)

    if n==0
        return _compute_scc(mm, 
                            year = year,
                            last_year = last_year,
                            prtp = prtp,
                            eta = eta,
                            discount_rates = discount_rates,
                            gas = gas,
                            CIAM_foresight = CIAM_foresight,
                            CIAM_GDPcap = CIAM_GDPcap,
                            pulse_size = pulse_size
                        )        
    else
        isnothing(discount_rates) ? error("To run the Monte Carlo compute_scc function (n != 0), please use the `discount_rates` argument.") : nothing
        
        # Set up output directories
        output_dir = output_dir === nothing ? joinpath(@__DIR__, "../output/mcs-SC/", "mcs_n$n") : output_dir
        isdir("$output_dir/results") || mkpath("$output_dir/results")

        return _compute_scc_mcs(mm, 
                                n,
                                year = year,
                                last_year = last_year,
                                discount_rates = discount_rates,
                                certainty_equivalent = certainty_equivalent,
                                fair_parameter_set = fair_parameter_set,
                                fair_parameter_set_ids = fair_parameter_set_ids,
                                rffsp_sampling = rffsp_sampling,
                                rffsp_sampling_ids = rffsp_sampling_ids,
                                gas = gas, 
                                save_list = save_list, 
                                output_dir = output_dir,
                                save_md = save_md,
                                save_cpc = save_cpc,
                                compute_sectoral_values = compute_sectoral_values,
                                CIAM_foresight = CIAM_foresight,
                                CIAM_GDPcap = CIAM_GDPcap,
                                post_mcs_creation_function = post_mcs_creation_function,
                                pulse_size = pulse_size,
                                compute_labor_country_sccs = compute_labor_country_sccs
                            )
    end
end

# Internal function to compute the SCC from a MarginalModel in a deterministic run
function _compute_scc(mm::MarginalModel;
                        year::Int,
                        last_year::Int,
                        prtp,
                        eta,
                        discount_rates,
                        gas::Symbol,
                        CIAM_foresight::Symbol,
                        CIAM_GDPcap::Bool,
                        pulse_size::Float64
                    )

    year_index = findfirst(isequal(year), _model_years)
    last_year_index = findfirst(isequal(last_year), _model_years)

    # Run all model years even if taking a shorter last_year - running unnecessary 
    # timesteps but simplifies accumulation             
    run(mm)

    # at this point create identical copies ciam_base and ciam_modified, they will 
    # be updated in MimiGIVE._compute_ciam_marginal_damages with update_ciam!
    ciam_base, segment_fingerprints = MimiGIVE.get_ciam(mm.base)
    ciam_modified, _ = MimiGIVE.get_ciam(mm.base) 

    ciam_base = Mimi.build(ciam_base)
    ciam_modified = Mimi.build(ciam_modified)

    # calculate ciam marginal damages (for globe, country, and domestic) only if 
    # we are including slr
    if mm.base[:DamageAggregator, :include_slr]

        all_ciam_marginal_damages = MimiGIVE._compute_ciam_marginal_damages(mm.base, mm.modified, gas, ciam_base, ciam_modified, segment_fingerprints; CIAM_foresight=CIAM_foresight, CIAM_GDPcap=CIAM_GDPcap,  pulse_size=pulse_size)
    
        # zero out the CIAM marginal damages from start year (2020) through emissions
        # year - they will be non-zero due to foresight but saved marginal damages
        # should be zero in the pre-emissions year
        all_ciam_marginal_damages.globe[1:year_index] .= 0.
        all_ciam_marginal_damages.domestic[1:year_index] .= 0.
        all_ciam_marginal_damages.country[1:year_index, :] .= 0.
    end
    
    # Units Note:
    #   main_marginal_damages: the marginal model will handle pulse size, we handle molecular mass conversion explicilty
    #   ciam_marginal_damages: within the MimiGIVE._compute_ciam_marginal_damages function we handle both pulse size and molecular mass
    main_marginal_damages = mm[:DamageAggregator, :total_damage] .* scc_gas_molecular_conversions[gas] 
    ciam_marginal_damages = mm.base[:DamageAggregator, :include_slr] ? all_ciam_marginal_damages.globe : fill(0., length(_model_years)) 

    marginal_damages = main_marginal_damages .+ ciam_marginal_damages
    
    # We don't care about units here because we are only going to use ratios
    cpc = mm.base[:global_netconsumption, :net_cpc]

    if discount_rates!==nothing

        sccs = Dict{NamedTuple{(:dr_label,:prtp,:eta),Tuple{Any,Float64,Float64}}, Float64}()
        
        for dr in discount_rates

            df = [((cpc[year_index]/cpc[i])^dr.eta * 1/(1+dr.prtp)^(t-year) for (i,t) in enumerate(_model_years) if year<=t<=last_year)...]
            scc = sum(df .* marginal_damages[year_index:last_year_index])

            # fill in the computed scc value
            sccs[(dr_label=dr.label, prtp=dr.prtp, eta=dr.eta)] = scc

        end # end discount rates loop

        return sccs
    else

        # Note that to use equity weighting, users will have to use the Named Tuple format of discount rates argument
        df = [((cpc[year_index]/cpc[i])^eta * 1/(1+prtp)^(t-year) for (i,t) in enumerate(_model_years) if year<=t<=last_year)...]
        scc = sum(df .* marginal_damages[year_index:last_year_index])

        return scc
    end
end

# Internal function to compute the SCC in a Monte Carlo Simulation
function _compute_scc_mcs(mm::MarginalModel, 
                            n; 
                            year::Int, 
                            last_year::Int, 
                            discount_rates, 
                            certainty_equivalent::Bool,
                            fair_parameter_set::Symbol = :random,
                            fair_parameter_set_ids::Union{Vector{Int}, Nothing} = nothing,
                            rffsp_sampling::Symbol = :random,
                            rffsp_sampling_ids::Union{Vector{Int}, Nothing} = nothing,
                            gas::Symbol, 
                            save_list::Vector, 
                            output_dir::String,
                            save_md::Bool,
                            save_cpc::Bool,
                            compute_sectoral_values::Bool,
                            CIAM_foresight::Symbol,
                            CIAM_GDPcap::Bool,
                            post_mcs_creation_function,
                            pulse_size::Float64,
                            compute_labor_country_sccs::Bool
                        )

    models = [mm.base, mm.modified]

    socioeconomics_module = MimiGIVE._get_module_name(mm.base, :Socioeconomic)
    if socioeconomics_module == :MimiSSPs
        socioeconomics_source = :SSP
    elseif socioeconomics_module == :MimiRFFSPs
        socioeconomics_source = :RFF
    end

    mcs = get_mcs(n; 
                    socioeconomics_source=socioeconomics_source, 
                    mcs_years = _model_years, 
                    fair_parameter_set = fair_parameter_set,
                    fair_parameter_set_ids = fair_parameter_set_ids,
                    rffsp_sampling = rffsp_sampling,
                    rffsp_sampling_ids = rffsp_sampling_ids,
                    save_list = save_list
                )
    
    if post_mcs_creation_function!==nothing
        post_mcs_creation_function(mcs)
    end

    sectors = compute_sectoral_values ? [:total,  :cromar_mortality, :agriculture, :energy, :labor, :slr] : [:total]
    regions = [:globe]

    scc_values = Dict((region=r, sector=s, dr_label=dr.label, prtp=dr.prtp, eta=dr.eta) => Vector{Union{Float64, Missing}}(undef, n) for dr in discount_rates, r in regions, s in sectors)
    intermediate_ce_scc_values = certainty_equivalent ? Dict((region=r, sector=s, dr_label=dr.label, prtp=dr.prtp, eta=dr.eta) => Vector{Float64}(undef, n) for dr in discount_rates, r in regions, s in sectors) : nothing
    md_values = save_md ? Dict((region=r, sector=s) => Array{Float64}(undef, n, length(_damages_years)) for r in regions, s in sectors) : nothing
    cpc_values = save_cpc ? Dict((region=r, sector=s) => Array{Float64}(undef, n, length(_damages_years)) for r in [:globe], s in [:total]) : nothing # just global and total for now
    norm_cpc_values_ce = certainty_equivalent ? Dict((region=r, sector=s) => Vector{Float64}(undef, n) for dr in discount_rates, r in [:globe], s in [:total]) : nothing
    labor_country_scc_values = compute_labor_country_sccs ? Dict((dr_label=dr.label, prtp=dr.prtp, eta=dr.eta) => Array{Union{Float64, Missing}}(undef, 184, n) for dr in discount_rates) : nothing

    ciam_base, segment_fingerprints = MimiGIVE.get_ciam(mm.base)
    ciam_modified, _ = MimiGIVE.get_ciam(mm.base)

    ciam_base = Mimi.build(ciam_base)
    ciam_modified = Mimi.build(ciam_modified)

    # set some computation options
    options = (
                compute_sectoral_values=compute_sectoral_values,
                save_md=save_md,
                save_cpc=save_cpc,
                CIAM_foresight=CIAM_foresight,
                CIAM_GDPcap=CIAM_GDPcap,
                certainty_equivalent=certainty_equivalent,
                pulse_size=pulse_size,
                compute_labor_country_sccs=compute_labor_country_sccs
            )

    payload = [scc_values, labor_country_scc_values, intermediate_ce_scc_values, norm_cpc_values_ce, md_values, cpc_values, year, last_year, discount_rates, gas, ciam_base, ciam_modified, segment_fingerprints, options]

    Mimi.set_payload2!(mcs, payload)

    # Run all model years even if taking a shorter last_year - running unnecessary 
    # timesteps but simplifies accumulation     
    sim_results = run(mcs, 
                        models, 
                        n, 
                        post_trial_func = post_trial_func,
                        results_in_memory = false,
                        results_output_dir = "$output_dir/results"
                    )

    # unpack the payload object
    scc_values, labor_country_scc_values,intermediate_ce_scc_values, norm_cpc_values_ce, md_values, cpc_values, year, last_year, discount_rates, gas, ciam_base, ciam_modified, segment_fingerprints, options = Mimi.payload2(sim_results)

    # Construct the returned result object
    result = Dict()

    # add an :scc dictionary, where key value pairs (k,v) are NamedTuples with keys(region, sector, dr_label, prtp, eta) => values are 281 element vectors (2020:2300)    result[:scc] = Dict()
    result[:scc] = Dict()
    for (k,v) in scc_values
        if certainty_equivalent
            # In this case the normalization from utils to $ hasn't happened in the post trial function
            # and instead we now do this here, based on expected per capita consumption in the year
            # of the marginal emission pulse

            # new key using all the same fields except making sector total and region global
            k_sector_total = (region=:globe, sector=:total)
            cpc_in_year_of_emission = norm_cpc_values_ce[k_sector_total]
            
            expected_mu_in_year_of_emission = mean(1 ./ (cpc_in_year_of_emission .^ k.eta))

            result[:scc][k] = (
                expected_scc = mean(v),
                se_expected_scc = std(v) / sqrt(n),
                ce_scc = mean(intermediate_ce_scc_values[k]) ./ expected_mu_in_year_of_emission,
                ce_sccs= intermediate_ce_scc_values[k] ./ expected_mu_in_year_of_emission,
                sccs = v,                
            )
        else
            result[:scc][k] = (
                expected_scc = mean(v),
                se_expected_scc = std(v) / sqrt(n),
                sccs = v
            )
        end
        
    end

    if compute_labor_country_sccs
        result[:labor_country_sccs] = Dict()
        for (k,v) in labor_country_scc_values
            result[:labor_country_sccs][k] = (
                expected_scc = mean(v, dims = 2),
                se_expected_scc = std(v, dims = 2) ./ sqrt(n),
                sccs = v
            )
        end
    end

    # add a :mds dictionary, where key value pairs (k,v) are NamedTuples with keys(region, sector) => values are (n x 281 (2020:2300)) matrices
    if save_md
        result[:mds] = Dict()
        for (k,v) in md_values
            result[:mds][k] = v
        end
    end

    # add a :cpc dictionary, where key value pairs (k,v) are NamedTuples with keys(region, sector) => values are (n x 281 (2020:2300)) matrices
    if save_cpc
        result[:cpc] = Dict()
        for (k,v) in cpc_values
            result[:cpc][k] = v
        end
    end

    return result
end

# Post trial function to to after each trial within the MCS
function post_trial_func(mcs::SimulationInstance, trialnum::Int, ntimesteps::Int, tup)

    # Unpack the payload object 
    scc_values, labor_country_scc_values, intermediate_ce_scc_values, norm_cpc_values_ce, md_values, cpc_values, year, last_year, discount_rates, gas, ciam_base, ciam_modified, segment_fingerprints, options = Mimi.payload2(mcs)

    # Compute some useful indices
    year_index = findfirst(isequal(year), _model_years)
    last_year_index = findfirst(isequal(last_year), _model_years)

    # Access the models
    base, marginal = mcs.models  # Access the models

    # Compute marginal damages
    # Units Note:
    #   main_mds and non-ciam sectoral damages: we explicitly need to handle both pulse size and molecular mass so we use gas_units_multiplier
    #   slr_mds: within the MimiGIVE._compute_ciam_marginal_damages function we handle both pulse size and molecular mass

    # Create a marginal model to use for computation of the marginal damages from
    # non-slr sectors, and IMPORTANTLY include the gas_units_multiplier as the 
    # `delta` attribute such that it is used to scale results and can be used for 
    # marginal damages calculations
    gas_units_multiplier = scc_gas_molecular_conversions[gas] ./ (scc_gas_pulse_size_conversions[gas] .* options.pulse_size)
    post_trial_mm = Mimi.MarginalModel(base, marginal, 1/gas_units_multiplier)

    include_slr = base[:DamageAggregator, :include_slr]
    if include_slr
        # return a NamedTuple with globe and domestic and country as well as other helper values
        ciam_mds = MimiGIVE._compute_ciam_marginal_damages(base, marginal, gas, ciam_base, ciam_modified, segment_fingerprints; CIAM_foresight=options.CIAM_foresight, CIAM_GDPcap=options.CIAM_GDPcap, pulse_size=options.pulse_size) 
        
        # zero out the CIAM marginal damages from start year (2020) through emissions
        # year - they will be non-zero due to foresight but saved marginal damages
        # should be zeroed out pre-emissions year
        ciam_mds.globe[1:year_index] .= 0.
        ciam_mds.domestic[1:year_index] .= 0.
        ciam_mds.country[1:year_index, :] .= 0.
    end
    
    main_mds = post_trial_mm[:DamageAggregator, :total_damage]
    slr_mds = include_slr ? ciam_mds.globe : fill(0., length(_model_years))
    total_mds = main_mds .+ slr_mds

    if options.compute_sectoral_values
        cromar_mortality_mds = post_trial_mm[:DamageAggregator, :cromar_mortality_damage]
        agriculture_mds = post_trial_mm[:DamageAggregator, :agriculture_damage]
        energy_mds = post_trial_mm[:DamageAggregator, :energy_damage]
        labor_mds = post_trial_mm[:DamageAggregator, :labor_damage]
    end

    if options.compute_labor_country_sccs
        labor_mds_country = post_trial_mm[:DamageAggregator, :damage_labor] .* 1e9 # convert from billion $ to $
    end

    # Save marginal damages
    if options.save_md

        # global
        md_values[(region=:globe, sector=:total)][trialnum, :] = total_mds[_damages_idxs]
        if options.compute_sectoral_values
            md_values[(region=:globe, sector=:cromar_mortality)][trialnum, :]   = cromar_mortality_mds[_damages_idxs]
            md_values[(region=:globe, sector=:agriculture)][trialnum, :]        = agriculture_mds[_damages_idxs]
            md_values[(region=:globe, sector=:energy)][trialnum, :]             = energy_mds[_damages_idxs]
            md_values[(region=:globe, sector=:labor)][trialnum, :]              = labor_mds[_damages_idxs]
            md_values[(region=:globe, sector=:slr)][trialnum, :]                = slr_mds[_damages_idxs]
        end
    end

    # Get per capita consumption
    # We don't care about units here because we are only going to use ratios
    cpc = base[:global_netconsumption, :net_cpc]
    
    # Save per capita consumption
    if options.save_cpc
        cpc_values[(region=:globe, sector=:total)][trialnum, :] = cpc[_damages_idxs]
    end

    # Calculate the SCC for each discount rate
    for dr in discount_rates

        df = [((cpc[year_index]/cpc[i])^dr.eta * 1/(1+dr.prtp)^(t-year) for (i,t) in enumerate(_model_years) if year<=t<=last_year)...]
        if options.certainty_equivalent
            df_ce = [((1. / cpc[i])^dr.eta * 1/(1+dr.prtp)^(t-year) for (i,t) in enumerate(_model_years) if year<=t<=last_year)...] # only used if optionas.certainty_equivalent=true
        end

        # totals (sector=:total)
        scc = sum(df .* total_mds[year_index:last_year_index])
        scc_values[(region=:globe, sector=:total, dr_label=dr.label, prtp=dr.prtp, eta=dr.eta)][trialnum] = scc
        if options.certainty_equivalent
            intermediate_ce_scc = sum(df_ce .* total_mds[year_index:last_year_index])
            intermediate_ce_scc_values[(region=:globe, sector=:total, dr_label=dr.label, prtp=dr.prtp, eta=dr.eta)][trialnum] = intermediate_ce_scc

            norm_cpc_values_ce[(region=:globe, sector=:total)][trialnum] = cpc[year_index]
        end

        # sectoral
        if options.compute_sectoral_values
            scc = sum(df .* cromar_mortality_mds[year_index:last_year_index])
            scc_values[(region=:globe, sector=:cromar_mortality, dr_label=dr.label, prtp=dr.prtp, eta=dr.eta)][trialnum] = scc

            scc = sum(df .* agriculture_mds[year_index:last_year_index])
            scc_values[(region=:globe, sector=:agriculture, dr_label=dr.label, prtp=dr.prtp, eta=dr.eta)][trialnum] = scc

            scc = sum(df .* energy_mds[year_index:last_year_index])
            scc_values[(region=:globe, sector=:energy, dr_label=dr.label, prtp=dr.prtp, eta=dr.eta)][trialnum] = scc

            scc = sum(df .* labor_mds[year_index:last_year_index])
            scc_values[(region=:globe, sector=:labor, dr_label=dr.label, prtp=dr.prtp, eta=dr.eta)][trialnum] = scc

            scc = sum(df .* slr_mds[year_index:last_year_index])
            scc_values[(region=:globe, sector=:slr, dr_label=dr.label, prtp=dr.prtp, eta=dr.eta)][trialnum] = scc

            if options.certainty_equivalent
                intermediate_ce_scc = sum(df_ce .* cromar_mortality_mds[year_index:last_year_index])
                intermediate_ce_scc_values[(region=:globe, sector=:cromar_mortality, dr_label=dr.label, prtp=dr.prtp, eta=dr.eta)][trialnum] = intermediate_ce_scc
    
                intermediate_ce_scc = sum(df_ce .* agriculture_mds[year_index:last_year_index])
                intermediate_ce_scc_values[(region=:globe, sector=:agriculture, dr_label=dr.label, prtp=dr.prtp, eta=dr.eta)][trialnum] = intermediate_ce_scc
    
                intermediate_ce_scc = sum(df_ce .* energy_mds[year_index:last_year_index])
                intermediate_ce_scc_values[(region=:globe, sector=:energy, dr_label=dr.label, prtp=dr.prtp, eta=dr.eta)][trialnum] = intermediate_ce_scc
    
                intermediate_ce_scc = sum(df_ce .* labor_mds[year_index:last_year_index])
                intermediate_ce_scc_values[(region=:globe, sector=:labor, dr_label=dr.label, prtp=dr.prtp, eta=dr.eta)][trialnum] = intermediate_ce_scc
    
                intermediate_ce_scc = sum(df_ce .* slr_mds[year_index:last_year_index])
                intermediate_ce_scc_values[(region=:globe, sector=:slr, dr_label=dr.label, prtp=dr.prtp, eta=dr.eta)][trialnum] = intermediate_ce_scc    
            end
        end

        # country level labor
        if options.compute_labor_country_sccs
            scc = vec(sum(df .* labor_mds_country[year_index:last_year_index,:], dims = 1)) # sum over time dimension, keep country dimension
            labor_country_scc_values[(dr_label=dr.label, prtp=dr.prtp, eta=dr.eta)][:, trialnum] = scc   
        end 

    end # end discount rates loop
end
