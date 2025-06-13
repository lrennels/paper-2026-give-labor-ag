using Mimi

output_dir = joinpath(@__DIR__, "output", "mcs")
mkpath(output_dir)

# Load all functions
include(joinpath(@__DIR__, "..", "src", "main.jl"))

# Settings
num_trials = 500
save_list = [
    (:Labor, :gcm),
    (:Labor, :laborcost),
    (:Agriculture, :gtap_impacts),
    (:Agriculture, :agcost),
]

# Get model and mcs
results = run_mcs(; trials = num_trials, output_dir = output_dir, save_list = save_list);

# Take a look at the mcs draws for agriculture -- should be triangular distributions
countries = ["USA", "ZAF", "CAN", "CHN", "IND", "BRA", "RUS", "AUS", "MEX", "JPN"]
gtap_impacts = load(joinpath(output_dir, "results", "Agriculture_gtap_impacts.csv")) |> 
    @filter(_.country in countries) |>
    DataFrame

rename!(gtap_impacts, Symbol("7") => :T)

gtap_impacts |> @vlplot(
                config = {
                                font = "Helvetica",
                                # style = {cell = {stroke = :transparent}},
                                axis = {
                                    labelFontSize = 7,
                                    titleFontSize = 7,
                                    domainColor = :black,
                                    tickColor = :black,
                                    titleFontWeight = :normal
                                },
                                legend = {
                                    labelFontSize = 7,
                                    titleFontSize = 7,
                                    # orient = "bottom-right",
                                    titleFontWeight = :normal,
                                    symbolSize = 25.
                                },
                                text = {fontSize = 7},
                                title = {fontSize = 8, anchor = :start}
                            },
                resolve = {scale = {y = :independent}},
                wrap = {:country, title = nothing},
                columns = 2,
                :bar,
                width = 200,
                height = 80,
                y = {"count()", title = "Count"},
                x = {:gtap_impacts, bin = {step = 0.025}, title = "GTAP Impact Frac"},
                color = {"T:o", title = "Temperature (deg c)", scale = {scheme = "magma", reverse = true}}
            ) |> save(joinpath(output_dir, "gtap_impacts_mcs_draws_bar.png"), ppi = 300)


gtap_impacts.gtap_impacts = Float64.(gtap_impacts.gtap_impacts)
gtap_impacts |> @vlplot(
                config = {
                    font = "Helvetica",
                    # style = {cell = {stroke = :transparent}},
                    axis = {
                        labelFontSize = 7,
                        titleFontSize = 7,
                        domainColor = :black,
                        tickColor = :black,
                        titleFontWeight = :normal
                    },
                    legend = {
                        labelFontSize = 7,
                        titleFontSize = 7,
                        # orient = "bottom-right",
                        titleFontWeight = :normal,
                        symbolSize = 25.
                    },
                    text = {fontSize = 7},
                    title = {fontSize = 8, anchor = :start}
                },
            resolve = {scale = {y = :independent}},
            wrap = {:country, title = nothing},
            columns = 2,
            # mark = {:area, opacity = 0.4},
            mark = {:line, size = 1.},
            transform=[
                {density = "gtap_impacts", counts = true, groupby = ["T", "country"]}
            ],
            width = 150,
            height = 40,
            y = {"density:q", stack = nothing, title = "Density"},
            x = {"value:q", title = "GTAP Impact Frac"},
            color = {"T:o", title = "Temperature (deg c)", scale = {scheme = "plasma", reverse = true}, legend = {symbolOpacity = 1.}}
        ) |> save(joinpath(output_dir, "gtap_impacts_mcs_draws_density.png"), ppi = 300)

# Take a look at the mcs draws for  labor -- should be uniform distributions
gcm = load(joinpath(output_dir, "results", "Labor_gcm.csv")) |> DataFrame
gcm |> @vlplot(
    config = {
                    font = "Helvetica",
                    # style = {cell = {stroke = :transparent}},
                    axis = {
                        labelFontSize = 7,
                        titleFontSize = 7,
                        domainColor = :black,
                        tickColor = :black,
                        titleFontWeight = :normal
                    },
                    legend = {
                        labelFontSize = 7,
                        titleFontSize = 7,
                        # orient = "bottom-right",
                        titleFontWeight = :normal,
                        symbolSize = 25.
                    },
                    text = {fontSize = 7},
                    title = {fontSize = 8, anchor = :start}
                },
            :bar,
            x = "count()",
            y = {:gcm, bin = {step = 1}}
            ) |> save(joinpath(output_dir, "gcm_draws.png"), ppi = 300)
