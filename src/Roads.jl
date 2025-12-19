module Roads

using Downloads: download
using osmium_jll

const LatLon = NamedTuple{(:lat, :lon), Tuple{Float32, Float32}}
LatLon(lat::Real, lon::Real) = (lat = Float32(lat), lon = Float32(lon))

const BoundingBox = NamedTuple{(:southwest, :northeast), Tuple{LatLon, LatLon}}
BoundingBox(southwest_lat::Real, southwest_lon::Real, northeast_lat::Real, northeast_lon::Real) = BoundingBox(LatLon(southwest_lat, southwest_lon), LatLon(northeast_lat, northeast_lon))

include("osmium/extract.jl")
include("osrm/profiles/profiles.jl")

export osmium_extract, truck_profile_path

end # module Roads
