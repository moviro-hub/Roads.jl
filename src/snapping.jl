using OpenSourceRoutingMachine.Nearest: Nearest
using OpenSourceRoutingMachine: OpenSourceRoutingMachine as OSRMs

mutable struct Location
    # street name, POI, etc
    name::Union{String, Nothing}
    # raw position & azimuth
    lat::Float32 # in degrees
    lon::Float32 # in degrees
    azimuth::Union{Float32, Nothing}
    # distance to road point
    distance::Union{Float32, Nothing}
    # OSRM hint
    osrm_hint::Union{String, Nothing}
end


function snap_location(
        instance::OSRMs.OSRM,
        position::LatLon;
        max_results::Integer = 1,
        radius::Union{Real, Nothing} = nothing,
        azimuth::Union{Real, Nothing} = nothing,
        azimuth_range::Integer = 15,
        snapping::Type{S} = SnappingKindDefault,
        approach::Type{A} = ApproachWaypointUnrestricted,
        excludes::Vector{String} = String[],
    ) where {S <: SnappingKind, A <: ApproachWaypoint}
    params = Nearest.NearestParams()
    Nearest.add_coordinate!(params, OSRMs.Position(position.lon, position.lat))

    Nearest.set_number_of_results!(params, max_results)
    if radius !== nothing
        Nearest.set_radius!(params, 1, radius)
    end
    if azimuth !== nothing
        Nearest.set_bearing!(params, 1, round(Int, azimuth), azimuth_range)
    end
    snapping = snapping_kind_to_snapping(snapping)
    Nearest.set_snapping!(params, snapping)
    approach = approach_waypoint_to_approach(approach)
    Nearest.set_approach!(params, 1, approach)

    for exclude in excludes
        Nearest.add_exclude!(params, exclude)
    end

    result = Nearest.nearest(instance, params)
    locations = Vector{Location}(undef, length(result.waypoints))
    for (i, waypoint) in enumerate(result.waypoints)
        locations[i] = Location(
            waypoint.name,
            position.lat,
            position.lon,
            azimuth,
            waypoint.distance,
            waypoint.hint,
        )
    end
    return locations
end
