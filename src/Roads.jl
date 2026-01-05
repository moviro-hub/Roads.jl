module Roads

using Downloads: download
using osmium_jll
using OpenSourceRoutingMachine: OpenSourceRoutingMachine as OSRMs
using OpenSourceRoutingMachine.Graph: Graph
using OpenSourceRoutingMachine.Nearest: Nearest
using OpenSourceRoutingMachine.Table: Table

const LatLon = NamedTuple{(:lat, :lon), Tuple{Float32, Float32}}
LatLon(lat::Real, lon::Real) = (lat = Float32(lat), lon = Float32(lon))

const BoundingBox = NamedTuple{(:southwest_lat, :southwest_lon, :northeast_lat, :northeast_lon), Tuple{Float32, Float32, Float32, Float32}}
BoundingBox(southwest_lat::Real, southwest_lon::Real, northeast_lat::Real, northeast_lon::Real) = BoundingBox(Float32(southwest_lat), Float32(southwest_lon), Float32(northeast_lat), Float32(northeast_lon))
BoundingBox(southwest::LatLon, northeast::LatLon) = BoundingBox(southwest.lat, southwest.lon, northeast.lat, northeast.lon)

include("subset.jl")
include("profiles/profiles.jl")
const PROFILE_TRUCK = truck_profile_path()
include("graph.jl")
include("snap.jl")
include("matrix.jl")

export creat_graph_files, truck_profile_path, snap_location, route_many_to_many

end # module Roads
