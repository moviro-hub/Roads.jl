module Roads

using Downloads: download
using osmium_jll
using OpenSourceRoutingMachine: OpenSourceRoutingMachine as OSRMs, OSRM,
    Verbosity, VERBOSITY_NONE, VERBOSITY_ERROR, VERBOSITY_WARNING, VERBOSITY_INFO, VERBOSITY_DEBUG,
    Snapping, SNAPPING_DEFAULT, SNAPPING_ANY,
    Approach, APPROACH_CURB, APPROACH_UNRESTRICTED, APPROACH_OPPOSITE
using OpenSourceRoutingMachine.Graph: Graph, Profile, PROFILE_CAR, PROFILE_BICYCLE, PROFILE_FOOT
using OpenSourceRoutingMachine.Nearest: Nearest
using OpenSourceRoutingMachine.Table: Table, TableAnnotations, TABLE_ANNOTATIONS_DURATION, TABLE_ANNOTATIONS_DISTANCE

# a truck routing profile
include("profiles/profiles.jl")
# overarching types
include("types.jl")
# subsetting OSM data
include("subset.jl")
# network creation
include("network.jl")
# snapping positions to the road network locations
include("snapping.jl")
# routing between locations
include("routing.jl")

# Re-export enums from OpenSourceRoutingMachine for convenience
export Verbosity, VERBOSITY_NONE, VERBOSITY_ERROR, VERBOSITY_WARNING, VERBOSITY_INFO, VERBOSITY_DEBUG
export Snapping, SNAPPING_DEFAULT, SNAPPING_ANY
export Approach, APPROACH_CURB, APPROACH_UNRESTRICTED, APPROACH_OPPOSITE
export Profile, PROFILE_CAR, PROFILE_BICYCLE, PROFILE_FOOT
export TableAnnotations, TABLE_ANNOTATIONS_DURATION, TABLE_ANNOTATIONS_DISTANCE
export LatLon, BBox
export OSRM
export subset_file, create_graph_files, snap_location, route_many_to_many

end # module Roads
