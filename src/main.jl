using Mimi

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
