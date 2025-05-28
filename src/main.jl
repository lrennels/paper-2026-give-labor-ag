using Mimi

# make sure to activate the right environment
using Pkg
Pkg.activate(".")

# utils
include("utils.jl")

# components
include("components/ag.jl")
include("components/labor.jl")
include("components/DamageAggregator.jl")

# get model
include("get_model.jl")

# advanced features
include("mcs.jl")
include("scc.jl")
