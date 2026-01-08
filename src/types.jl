# named tuple types
const LatLon = NamedTuple{(:lat, :lon), Tuple{Float32, Float32}}
LatLon(lat::Real, lon::Real) = (lat = Float32(lat), lon = Float32(lon))

const BBox = NamedTuple{(:southwest_lat, :southwest_lon, :northeast_lat, :northeast_lon), Tuple{Float32, Float32, Float32, Float32}}
BBox(southwest_lat::Real, southwest_lon::Real, northeast_lat::Real, northeast_lon::Real) = (southwest_lat = Float32(southwest_lat), southwest_lon = Float32(southwest_lon), northeast_lat = Float32(northeast_lat), northeast_lon = Float32(northeast_lon))
BBox(southwest::LatLon, northeast::LatLon) = (southwest_lat = southwest.lat, southwest_lon = southwest.lon, northeast_lat = northeast.lat, northeast_lon = northeast.lon)
