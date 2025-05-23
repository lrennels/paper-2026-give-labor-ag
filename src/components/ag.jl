using Mimi

# Agriculture impacts component

@defcomp Agriculture begin

    # Parameters
    ypc90 = Parameter(index=[time, country], unit="US\$2005/yr/person")
    gdp = Parameter(index=[time, country], unit="billion US\$2005/yr")
    population = Parameter(index=[time, country], unit = "million")

    agrish0 = Parameter(index=[country]) # initial share in 2017
    agel = Parameter(default = 0.31) # elasticity (FUND)

    temp = Parameter(index=[time], unit="degC")
    gtap_impacts = Parameter(index=[country, 7]) # seven temperature data points per country 1:0.5:4

    # Variables
    agrish = Variable(index=[time,country]) # agricultural share of the economy
    agloss_gtap_frac = Variable(index=[time, country]) # fractional loss - intermediate variable for calculating agcost
    agcost = Variable(index=[time,country], unit="billion US\$2005/yr")

    function run_timestep(p,v,d,t)
        for c in d.country
            
            v.agrish[t, c] = p.agrish0[c] * (ypc / p.ypc90[c])^(-p.agel)

            # Interpolate using the seven gtap welfare points with the additional origin (0,0) point
            impact = linear_interpolate([0, p.gtap_impacts[c, :]...], [0., collect(1:0.5:4)...], p.temp[t])
            v.agloss_gtap_frac[t, c] = -1 * impact # take the negative to go from impact to loss

            # Calculate total cost for the ag sector based on the fractional loss
            v.agcost[t, c] = p.gdp[t, c] * v.agrish[t, r] * v.agloss_gtap_frac[t, c]
        end
    end
end

