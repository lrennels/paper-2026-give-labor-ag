using Mimi

output_dir = joinpath(@__DIR__, "output", "mcs")
mkpath(output_dir)

# Load all functions
include(joinpath(@__DIR__, "..", "src", "main.jl"))

# Settings
num_trials = 100
save_list = [
    (:Labor, :gcm),
    (:Labor, :laborcost),
    (:Agriculture, :gtap_impacts),
    (:Agriculture, :agcost),
]

# Get model and mcs
results = run_mcs(; trials = num_trials, output_dir = output_dir, save_list = save_list);

# Take a look at the mcs draws for agriculture -- should be triangular distributions (TODO)

# Take a look at the mcs draws for  labor -- should be uniform distributions (TODO)
