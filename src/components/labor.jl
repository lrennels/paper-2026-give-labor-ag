using Mimi

# Labor impacts component

@defcomp Labor begin

    gcm = Index() # 16 gcm indices, the first is the ensemble and the next 15 are individual GCMs

    # Parameters
    gdp = Parameter(index=[time, country], unit="billion US\$2005/yr")
    population = Parameter(index=[time, country], unit = "million")
    temp = Parameter(index=[time], unit="degC")
    gcm = Parameter{Int}(default = 1)
    gtap_impacts = Parameter(index=[country, 7, gcm])  # seven temperature data points per country 1:0.5:4

    # Variables
    laborloss_gtap_frac = Variable(index=[time, country]) # fractional loss - intermediate variable for calculating laborcost
    laborcost = Variable(index=[time,country], unit="billion US\$2005/yr")

    function run_timestep(p,v,d,t)
        for c in d.countries

            # Interpolate using the seven gtap welfare points with the additional origin (0,0) point
            impact = linear_interpolate([0, p.gtap_impacts[c, :, gcm]...], collect(0:0.5:4), p.temp[t])
            v.laborloss_gtap_frac[t, c] = -1 * impact # take the negative to go from impact to loss

            # Calculate total cost for the labor sector based on the fractional loss
            v.laborcost[t, c] = p.gdp[t, c] * v.laborloss_gtap_frac[t, c]
        end
    end
end
