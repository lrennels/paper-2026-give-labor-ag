using Mimi

# Agriculture impacts component

@defcomp Agriculture begin

    # Parameters
    gdp = Parameter(index=[time, country], unit="billion US\$2005/yr")
    agrish = Parameter(index=[time,country]) # agricultural share of the economy
    temp = Parameter(index=[time], unit="degC")
    gtap_impacts = Parameter(index=[country, 7]) # seven temperature data points per country 1:0.5:4

    # Variables
    agloss_gtap_frac = Variable(index=[time, country]) # fractional loss - intermediate variable for calculating agcost
    agcost = Variable(index=[time,country], unit="billion US\$2005/yr")

    function run_timestep(p,v,d,t)
        for c in d.country

            # Interpolate using the seven gtap welfare points with the additional origin (0,0) point
            impact = linear_interpolate([0, p.gtap_impacts[c, :]...], [0., collect(1:0.5:4)...], p.temp[t])
            v.agloss_gtap_frac[t, c] = -1 * impact # take the negative to go from impact to loss

            # Calculate total cost for the ag sector based on the fractional loss
            v.agcost[t, c] = p.gdp[t, c] * p.agrish[t, c] * v.agloss_gtap_frac[t, c]
        end
    end
end
