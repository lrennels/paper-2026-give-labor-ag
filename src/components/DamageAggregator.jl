using Mimi

# Aggregate damages across damage functions
# Adapted from MimiGIVE DamageAggregator.jl

@defcomp DamageAggregator begin

    # inclusion of different damages

    # By default the individual sectoral damage calculations are ON, including 
    # SLR which runs after the main model, while global damage function calculations
    # are OFF.
    include_cromar_mortality = Parameter{Bool}(default=true)
    include_ag = Parameter{Bool}(default=true)
    include_labor = Parameter{Bool}(default=true)
    include_slr = Parameter{Bool}(default=true)
    include_energy = Parameter{Bool}(default=true)
    include_dice2016R2 = Parameter{Bool}(default=false)
    include_hs_damage = Parameter{Bool}(default=false)

    damage_cromar_mortality = Parameter(index=[time,country], unit="US\$2005/yr")
    damage_ag = Parameter(index=[time,country], unit="billion US\$2005/yr")
    damage_labor = Parameter(index=[time,country], unit="billion US\$2005/yr")
    damage_energy = Parameter(index=[time,energy_countries], unit="billion US\$2005/yr")
    damage_dice2016R2 = Parameter(index=[time], unit="billion US\$2005/yr")
    damage_hs = Parameter(index=[time], unit="billion US\$2005/yr")

    gdp = Parameter(index=[time,country], unit="billion US\$2005/yr")

    total_damage = Variable(index=[time], unit="US\$2005/yr")
    total_damage_countries = Variable(index=[time, country], unit="US\$2005/yr") # ag damages disaggregated via method in AgricultureDamagesDisaggregator
    total_damage_share = Variable(index=[time])

    # global annual aggregates - for interim model outputs and partial SCCs
    cromar_mortality_damage = Variable(index=[time], unit="US\$2005/yr")
    agriculture_damage      = Variable(index=[time], unit="US\$2005/yr")
    labor_damage            = Variable(index=[time], unit="US\$2005/yr")
    energy_damage           = Variable(index=[time], unit="US\$2005/yr")

    function run_timestep(p, v, d, t)

        # country level aggregates
        num_countries = length(d.country)
        v.total_damage_countries[t,:] =
            (p.include_cromar_mortality ? p.damage_cromar_mortality[t,:] : fill(0., num_countries)) +
            (p.include_ag               ? p.damage_ag[t,:] * 1e9 : fill(0., num_countries)) +
            (p.include_labor            ? p.damage_labor[t,:] * 1e9 : fill(0., num_countries)) +
            (p.include_energy           ? p.damage_energy[t,:] * 1e9 : fill(0., num_countries))

        # global annual aggregates - for interim model outputs and partial SCCs
        v.cromar_mortality_damage[t]    = sum(p.damage_cromar_mortality[t,:])
        v.agriculture_damage[t]         = sum(p.damage_ag[t,:]) * 1e9 
        v.labor_damage[t]               = sum(p.damage_labor[t,:]) * 1e9 
        v.energy_damage[t]              = sum(p.damage_energy[t,:]) * 1e9

        v.total_damage[t] =
            (p.include_cromar_mortality ? v.cromar_mortality_damage[t] : 0.) +
            (p.include_ag               ? v.agriculture_damage[t] : 0.) +
            (p.include_labor            ? v.labor_damage[t] : 0.) +
            (p.include_energy           ? v.energy_damage[t] : 0.) +
            (p.include_dice2016R2       ? p.damage_dice2016R2[t] * 1e9 : 0.) +
            (p.include_hs_damage        ? p.damage_hs[t] * 1e9 : 0.)

        gdp = sum(p.gdp[t,:]) * 1e9

        v.total_damage_share[t] = v.total_damage[t] / gdp

    end
end
