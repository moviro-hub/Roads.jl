using OpenSourceRoutingMachine: OpenSourceRoutingMachine as OSRMs
using OpenSourceRoutingMachine.Table: Table, TableAnnotations, TABLE_ANNOTATIONS_DURATION, TableFallbackCoordinate, TABLE_FALLBACK_COORDINATE_INPUT

struct ManyToManyMetric
    locations::Vector{Location}
    origin_indices::Vector{Int64}
    destination_indices::Vector{Int64}
    metrics::Union{Matrix{Float32}, Nothing}
    metric_type::Symbol
end

function route_many_to_many(
        instance::OSRMs.OSRM,
        locations::Vector{Location};
        origin_indices::AbstractVector{Int} = 1:length(locations),
        destination_indices::AbstractVector{Int} = 1:length(locations),
        annotation::TableAnnotations = TABLE_ANNOTATIONS_DURATION,
        fallback_speed::Union{Real, Nothing} = nothing,
        fallback_coordinate_type::TableFallbackCoordinate = TABLE_FALLBACK_COORDINATE_INPUT,
        scale_factor::Union{Real, Nothing} = nothing,
    )

    params = Table.TableParams()
    for (idx, location) in enumerate(locations)
        Table.add_coordinate!(params, OSRMs.Position(location.lon, location.lat))
        if location.osrm_hint !== nothing
            Table.set_hint!(params, idx, location.osrm_hint)
        end
    end
    for origin_index in origin_indices
        Table.add_source!(params, origin_index)
    end
    for destination_index in destination_indices
        Table.add_destination!(params, destination_index)
    end
    # TODO: Once we move to the new `libosrmc` version, we can remove this and use the annotation parameter directly
    Table.set_annotations!(params, TABLE_ANNOTATIONS_DURATION | TABLE_ANNOTATIONS_DISTANCE)
    Table.set_fallback_coordinate_type!(params, fallback_coordinate_type)
    if fallback_speed !== nothing
        Table.set_fallback_speed!(params, fallback_speed)
    end
    if scale_factor !== nothing
        Table.set_scale_factor!(params, scale_factor)
    end
    # compute the matrix
    result = Table.table(instance, params)
    # extract the matrix based on requested annotation type
    if annotation == TABLE_ANNOTATIONS_DISTANCE
        if isempty(result.table.distances)
            throw(ArgumentError("Distance annotation requested but distances array is empty. This may indicate an issue with the OSRM configuration or data."))
        end
        metric_matrix = permutedims(reshape(result.table.distances, result.table.cols, result.table.rows), (2, 1))
        metric_type = :distance
    elseif annotation == TABLE_ANNOTATIONS_DURATION
        if isempty(result.table.durations)
            throw(ArgumentError("Duration annotation requested but durations array is empty. This may indicate an issue with the OSRM configuration or data."))
        end
        metric_matrix = permutedims(reshape(result.table.durations, result.table.cols, result.table.rows), (2, 1)) .* 60.0
        metric_type = :duration
    else
        throw(ArgumentError("annotation must be TABLE_ANNOTATIONS_DISTANCE or TABLE_ANNOTATIONS_DURATION"))
    end
    return ManyToManyMetric(locations, collect(origin_indices), collect(destination_indices), metric_matrix, metric_type)
end
