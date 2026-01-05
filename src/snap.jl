using OpenSourceRoutingMachine.Nearest: Nearest
using OpenSourceRoutingMachine: OpenSourceRoutingMachine as OSRMs

mutable struct Location
    # street name, POI, etc
    name::Union{String, Nothing} = nothing
    # raw position & azimuth
    lat::Float32 # in degrees
    lon::Float32 # in degrees
    azimuth::Union{Float32, Nothing} = nothing # in degrees
    # distance to road point
    distance::Union{Float32, Nothing} = nothing # in meters
    # OSRM hint
    osrm_hint::Union{String, Nothing} = nothing
end


function snap_location(
        instance::OSRMs.OSRM,
        position::LatLon;
        max_results::Union{Integer, Nothing} = nothing,
        radius::Union{Real, Nothing} = nothing,
        azimuth::Union{Real, Nothing} = nothing,
        azimuth_range::Integer = 15,
        snapping::Union{OSRMs.Snapping, Nothing} = nothing,
        approach::Union{OSRMs.Approach, Nothing} = nothing,
        excludes::Union{Vector{String}, Nothing} = nothing,
    )
    params = Nearest.NearestParams()
    Nearest.add_coordinate!(params, OSRMs.Position(position.lon, position.lat))

    if max_results !== nothing
        Nearest.set_number_of_results!(params, max_results)
    end
    if radius !== nothing
        Nearest.set_radius!(params, 1, radius)
    end
    if azimuth !== nothing
        Nearest.set_bearing!(params, 1, round(Int, azimuth), azimuth_range)
    end
    if snapping !== nothing
        Nearest.set_snapping!(params, snapping)
    end
    if approach !== nothing
        Nearest.set_approach!(params, 1, approach)
    end
    if excludes !== nothing
        for exclude in excludes
            Nearest.add_exclude!(params, exclude)
        end
    end

    result = Nearest.nearest(instance, params)
    locations = Vector{Location}(undef, length(result.waypoints))
    for (i, waypoint) in enumerate(result.waypoints)
        locations[i] = Location(
            waypoint.name,
            waypoint.position.latitude,
            waypoint.position.longitude,
            waypoint.bearing,
            waypoint.distance,
            waypoint.hint,
        )
    end
    return locations
end
