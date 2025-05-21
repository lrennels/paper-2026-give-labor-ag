using Mimi, Interpolations

@defcomp Agriculture begin

    # Parameters
    gdp2017 = Parameter(index=[time], unit="billion US\$2005/yr")
    gdp = Parameter(index=[time, country], unit="billion US\$2005/yr")
    population2017 = Parameter(index=[time], unit = "million")
    population = Parameter(index=[time, country], unit = "million")

    agrish0 = Parameter(index=[country]) # initial share 
    agel = Parameter(default = 0.31) # elasticity

    temp = Parameter(index=[time], unit="degC")
    gtap_impacts = Parameter(index=[country, 7])  # seven temperature data points per country 1:0.5:4

    # Variables
    agrish = Variable(index=[time,country]) # agricultural share of the economy
    agloss_gtap = Variable(index=[time, country]) # fractional loss - intermediate variable for calculating agcost
    agcost = Variable(index=[time,country]) # the main damage variable

    function run_timestep(p,v,d,t)
        for c in d.countries
            
            ypc = (1_000 * p.gdp[t,c]) / p.population[t,c] # USD per person
            ypc90 = (1_000 * p.gdp2017[c]) / p.pop90[c] # USD per person
            
            v.agrish[t, c] = p.agrish0[c] * (ypc / ypc90)^(-p.agel)

            # Interpolate using the seven gtap welfare points with the additional origin (0,0) point
            impact = linear_interpolate([0, p.gtap_impacts[c, :]...], collect(0:0.5:4), p.temp[t])
            v.agloss_gtap[t, c] = -1 * impact # take the negative to go from impact to loss

            # Calculate total cost for the ag sector based on the percent loss
            v.agcost[t, c] = p.gdp[t, c] * v.agrish[t, r] * v.agloss_gtap[t, c]
        end
    end
end

