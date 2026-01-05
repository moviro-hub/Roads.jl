struct ManyToManyMetric
    locations::Vector{Location}
    origin_indices::Vector{Int}
    destination_indices::Vector{Int}
    durations::Union{Matrix{Float32}, Nothing}
    distances::Union{Matrix{Float32}, Nothing}
end

function route_many_to_many(
        instance::OSRMs.OSRM,
        locations::Vector{Location};
        origin_indices::Vector{Int},
        destination_indices::Vector{Int},
        annotations::Union{Table.TableAnnotations, Nothing} = nothing,
        fallback_speed::Union{Real, Nothing} = nothing,
        scale_factor::Union{Real, Nothing} = nothing,
    )
    params = Table.TableParams()
    for (idx, location) in enumerate(locations)
        Table.add_coordinate!(params, OSRMs.Position(location.lon, location.lat))
        if location.osrm_hint !== nothing
            Table.set_hint!(params, idx, location.osrm_hint)
        end
        if radius !== nothing
            Table.set_radius!(params, idx, radius)
        end
    end
    for origin_index in origin_indices
        Table.add_source!(params, origin_index)
    end
    for destination_index in destination_indices
        Table.add_destination!(params, destination_index)
    end
    if annotations !== nothing
        Table.set_annotations!(params, annotations)
    end
    if fallback_speed !== nothing
        Table.set_fallback_coordinate_type!(params, Table.TABLE_FALLBACK_COORDINATE_INPUT)
        Table.set_fallback_speed!(params, fallback_speed)
    end
    if scale_factor !== nothing
        Table.set_scale_factor!(params, scale_factor)
    end
    # compute the matrix
    result = Table.table(instance, params)
    # extract the matrix
    if length(result.table.distances) > 0
        distances_matrix = permutedims(reshape(result.table.distances, result.table.cols, result.table.rows), (2, 1))
    else
        distances_matrix = nothing
    end
    if length(result.table.durations) > 0
        durations_matrix = permutedims(reshape(result.table.durations, result.table.cols, result.table.rows), (2, 1))
    else
        durations_matrix = nothing
    end
    return ManyToManyMetric(locations, origin_indices, destination_indices, durations_matrix, distances_matrix)
end
