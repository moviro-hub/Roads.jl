module Roads

using Downloads: download
using osmium_jll
using OpenSourceRoutingMachine: OpenSourceRoutingMachine as OSRMs, OSRM
using OpenSourceRoutingMachine.Graph: Graph
using OpenSourceRoutingMachine.Nearest: Nearest
using OpenSourceRoutingMachine.Table: Table

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

export TravelMode, TravelModeCar, TravelModeBicycle, TravelModeFoot, TravelModeTruck
export LogLevel, LogLevelNone, LogLevelError, LogLevelWarning, LogLevelInfo, LogLevelDebug
export SnappingKind, SnappingKindAny, SnappingKindDefault
export LatLon, BBox
export OSRM
export subset_file, create_graph_files, snap_location, route_many_to_many

end # module Roads
