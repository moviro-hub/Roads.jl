# named tuple types
const LatLon = NamedTuple{(:lat, :lon), Tuple{Float32, Float32}}
LatLon(lat::Real, lon::Real) = (lat = Float32(lat), lon = Float32(lon))

const BBox = NamedTuple{(:southwest_lat, :southwest_lon, :northeast_lat, :northeast_lon), Tuple{Float32, Float32, Float32, Float32}}
BBox(southwest_lat::Real, southwest_lon::Real, northeast_lat::Real, northeast_lon::Real) = BBox(Float32(southwest_lat), Float32(southwest_lon), Float32(northeast_lat), Float32(northeast_lon))
BBox(southwest::LatLon, northeast::LatLon) = BBox(southwest.lat, southwest.lon, northeast.lat, northeast.lon)


# enum-like types
abstract type TravelMode end
struct TravelModeFoot <: TravelMode end
struct TravelModeBicycle <: TravelMode end
struct TravelModeCar <: TravelMode end
struct TravelModeTruck <: TravelMode end

travel_mode_to_profile(mode::Type{<:TravelMode}) = throw(ArgumentError("mode must be a TravelMode subtype"))
travel_mode_to_profile(mode::Type{TravelModeCar}) = Graph.PROFILE_CAR
travel_mode_to_profile(mode::Type{TravelModeBicycle}) = Graph.PROFILE_BICYCLE
travel_mode_to_profile(mode::Type{TravelModeFoot}) = Graph.PROFILE_FOOT
travel_mode_to_profile(mode::Type{TravelModeTruck}) = truck_profile_path()

abstract type LogLevel end
struct LogLevelNone <: LogLevel end
struct LogLevelError <: LogLevel end
struct LogLevelWarning <: LogLevel end
struct LogLevelInfo <: LogLevel end
struct LogLevelDebug <: LogLevel end

log_level_to_verbosity(level::Type{<:LogLevel}) = throw(ArgumentError("level must be a LogLevel subtype"))
log_level_to_verbosity(level::Type{LogLevelNone}) = OSRMs.VERBOSITY_NONE
log_level_to_verbosity(level::Type{LogLevelError}) = OSRMs.VERBOSITY_ERROR
log_level_to_verbosity(level::Type{LogLevelWarning}) = OSRMs.VERBOSITY_WARNING
log_level_to_verbosity(level::Type{LogLevelInfo}) = OSRMs.VERBOSITY_INFO
log_level_to_verbosity(level::Type{LogLevelDebug}) = OSRMs.VERBOSITY_DEBUG

abstract type SnappingKind end
struct SnappingKindAny <: SnappingKind end
struct SnappingKindDefault <: SnappingKind end

snapping_kind_to_snapping(snapping::Type{<:SnappingKind}) = throw(ArgumentError("snapping must be a SnappingKind subtype"))
snapping_kind_to_snapping(snapping::Type{SnappingKindAny}) = OSRMs.SNAPPING_ANY
snapping_kind_to_snapping(snapping::Type{SnappingKindDefault}) = OSRMs.SNAPPING_DEFAULT

abstract type ApproachWaypoint end
struct ApproachWaypointUnrestricted <: ApproachWaypoint end
struct ApproachWaypointCurbSide <: ApproachWaypoint end
struct ApproachWaypointNonCurbSide <: ApproachWaypoint end

approach_waypoint_to_approach(approach::Type{<:ApproachWaypoint}) = throw(ArgumentError("approach must be a ApproachWaypoint subtype"))
approach_waypoint_to_approach(approach::Type{ApproachWaypointUnrestricted}) = OSRMs.APPROACH_UNRESTRICTED
approach_waypoint_to_approach(approach::Type{ApproachWaypointCurbSide}) = OSRMs.APPROACH_CURB
approach_waypoint_to_approach(approach::Type{ApproachWaypointNonCurbSide}) = OSRMs.APPROACH_OPPOSITE

abstract type RoutingMetric end
struct RoutingMetricDuration <: RoutingMetric end
struct RoutingMetricDistance <: RoutingMetric end

routing_metric_to_annotation(metric::Type{<:RoutingMetric}) = throw(ArgumentError("metric must be a RoutingMetric subtype"))
routing_metric_to_annotation(metric::Type{RoutingMetricDuration}) = Table.TABLE_ANNOTATIONS_DURATION
routing_metric_to_annotation(metric::Type{RoutingMetricDistance}) = Table.TABLE_ANNOTATIONS_DISTANCE
