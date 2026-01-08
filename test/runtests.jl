using Test
using Roads

@testset "Roads" begin
    include("subset_tests.jl")
    include("network_tests.jl")
    include("snapping_tests.jl")
    include("routing_tests.jl")
end
