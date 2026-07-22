using Mimi

# utils
include("utils.jl")

# components
include("components/AgricultureShare.jl")
include("components/Agriculture.jl")
include("components/Labor.jl")
include("components/DamageAggregator.jl")

# get model
include("get_model.jl")

# advanced features
include("mcs.jl")
include("scc.jl")
