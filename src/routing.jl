struct ManyToManyMetric
    locations::Vector{Location}
    origin_indices::Vector{Int64}
    destination_indices::Vector{Int64}
    metrics::Union{Matrix{Float32}, Nothing}
    metric_type::Type{<:RoutingMetric}
end

function route_many_to_many(
        instance::OSRMs.OSRM,
        locations::Vector{Location};
        origin_indices::AbstractVector{Int} = 1:length(locations),
        destination_indices::AbstractVector{Int} = 1:length(locations),
        # routing_metric::Type{M} = RoutingMetricDuration,
        fallback_speed::Union{Real, Nothing} = nothing,
        scale_factor::Union{Real, Nothing} = nothing,
    ) where {M <: RoutingMetric}

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
    annotation = routing_metric_to_annotation(routing_metric)
    # TODO: This has a bug in the  C API which needs a fix first
    # Table.set_annotations!(params, annotation)
    Table.set_fallback_coordinate_type!(params, Table.TABLE_FALLBACK_COORDINATE_INPUT)
    if fallback_speed !== nothing
        Table.set_fallback_speed!(params, fallback_speed)
    end
    if scale_factor !== nothing
        Table.set_scale_factor!(params, scale_factor)
    end
    # compute the matrix
    result = Table.table(instance, params)
    # extract the matrix
    # if routing_metric == RoutingMetricDistance
    #     metric_matrix = permutedims(reshape(result.table.distances, result.table.cols, result.table.rows), (2, 1))
    # elseif routing_metric == RoutingMetricDuration
    metric_matrix = permutedims(reshape(result.table.durations, result.table.cols, result.table.rows), (2, 1)) .* 60.0
    # else
    #     throw(ArgumentError("routing_metric must be a RoutingMetric subtype"))
    # end
    return ManyToManyMetric(locations, collect(origin_indices), collect(destination_indices), metric_matrix, routing_metric)
end
