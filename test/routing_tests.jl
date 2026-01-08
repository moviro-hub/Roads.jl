using Test
using Roads
using Roads.OSRMs
using Roads.OSRMs.Table: TableAnnotations, TABLE_ANNOTATIONS_DURATION, TABLE_ANNOTATIONS_DISTANCE, TableFallbackCoordinate, TABLE_FALLBACK_COORDINATE_INPUT

# Test data paths
const TEST_DATA_DIR = joinpath(@__DIR__, "data")
const HAMBURG_OSM_PATH = joinpath(TEST_DATA_DIR, "hamburg-latest.osm.pbf")

# Hamburg coordinates for testing
const HAMBURG_CITY_CENTER = LatLon(53.5511, 9.9937)
const HAMBURG_AIRPORT = LatLon(53.6325, 10.006)
const HAMBURG_PORT = LatLon(53.5301, 9.9691)

# Cache for the test OSRM instance
const _test_osrm_cache = Ref{Union{OSRM, Nothing}}(nothing)

"""
Get a test OSRM instance, building the graph if necessary.
"""
function get_test_osrm()::OSRM
    if _test_osrm_cache[] === nothing
        # Build OSRM graph if it doesn't exist
        osrm_base_path = joinpath(TEST_DATA_DIR, "hamburg-latest.osrm")

        if !isfile("$osrm_base_path.partition")
            @info "Building OSRM graph for tests..."
            create_graph_files(HAMBURG_OSM_PATH, osrm_base_path; travel_mode = PROFILE_CAR)
        end

        _test_osrm_cache[] = OSRM(osrm_base_path)
    end
    return _test_osrm_cache[]
end

@testset "route_many_to_many" begin
    osrm = get_test_osrm()

    # Create test locations by snapping known coordinates
    city_center_locs = snap_location(osrm, HAMBURG_CITY_CENTER; max_results = 1)
    airport_locs = snap_location(osrm, HAMBURG_AIRPORT; max_results = 1)
    port_locs = snap_location(osrm, HAMBURG_PORT; max_results = 1)

    @test !isempty(city_center_locs)
    @test !isempty(airport_locs)
    @test !isempty(port_locs)

    locations = [city_center_locs[1], airport_locs[1], port_locs[1]]

    @testset "Basic routing" begin
        # Test basic many-to-many routing with default parameters
        result = route_many_to_many(osrm, locations)

        @test result isa Roads.ManyToManyMetric
        @test result.locations == locations
        @test result.origin_indices == [1, 2, 3]
        @test result.destination_indices == [1, 2, 3]
        @test result.metrics isa Matrix{Float32}
        @test size(result.metrics) == (3, 3)
        @test result.metric_type == :duration
    end

    @testset "Distance annotation" begin
        # Test with distance annotation
        result = route_many_to_many(osrm, locations; annotation = TABLE_ANNOTATIONS_DISTANCE)

        @test result.metric_type == :distance
        @test result.metrics isa Matrix{Float32}
        @test size(result.metrics) == (3, 3)

        # Distance should be non-negative
        for i in 1:size(result.metrics, 1)
            for j in 1:size(result.metrics, 2)
                @test result.metrics[i, j] >= 0.0f0
            end
        end
    end

    @testset "Duration annotation" begin
        # Test with duration annotation (default)
        result = route_many_to_many(osrm, locations; annotation = TABLE_ANNOTATIONS_DURATION)

        @test result.metric_type == :duration
        @test result.metrics isa Matrix{Float32}
        @test size(result.metrics) == (3, 3)

        # Duration should be non-negative
        for i in 1:size(result.metrics, 1)
            for j in 1:size(result.metrics, 2)
                @test result.metrics[i, j] >= 0.0f0
            end
        end
    end

    @testset "Origin and destination indices" begin
        # Test with custom origin and destination indices
        result = route_many_to_many(
            osrm,
            locations;
            origin_indices = [1, 2],
            destination_indices = [2, 3]
        )

        @test result.origin_indices == [1, 2]
        @test result.destination_indices == [2, 3]
        @test size(result.metrics) == (2, 2)

        # Metrics should be for origins [1,2] to destinations [2,3]
        # result.metrics[1, 1] should be from location 1 to location 2
        # result.metrics[1, 2] should be from location 1 to location 3
        # result.metrics[2, 1] should be from location 2 to location 2
        # result.metrics[2, 2] should be from location 2 to location 3
        @test result.metrics[1, 1] >= 0.0f0  # 1 -> 2
        @test result.metrics[1, 2] >= 0.0f0  # 1 -> 3
        @test result.metrics[2, 1] >= 0.0f0  # 2 -> 2 (should be 0 or small)
        @test result.metrics[2, 2] >= 0.0f0  # 2 -> 3
    end

    @testset "Single origin to multiple destinations" begin
        # Test routing from one origin to multiple destinations
        result = route_many_to_many(
            osrm,
            locations;
            origin_indices = [1],
            destination_indices = [1, 2, 3]
        )

        @test result.origin_indices == [1]
        @test result.destination_indices == [1, 2, 3]
        @test size(result.metrics) == (1, 3)

        # Distance from location 1 to itself should be 0 or very small
        @test result.metrics[1, 1] >= 0.0f0
    end

    @testset "Multiple origins to single destination" begin
        # Test routing from multiple origins to one destination
        result = route_many_to_many(
            osrm,
            locations;
            origin_indices = [1, 2, 3],
            destination_indices = [2]
        )

        @test result.origin_indices == [1, 2, 3]
        @test result.destination_indices == [2]
        @test size(result.metrics) == (3, 1)

        # Distance from location 2 to itself should be 0 or very small
        @test result.metrics[2, 1] >= 0.0f0
    end

    @testset "Fallback parameters" begin
        # Test with fallback speed
        result = route_many_to_many(
            osrm,
            locations;
            fallback_speed = 50.0
        )

        @test result.metrics isa Matrix{Float32}
        @test size(result.metrics) == (3, 3)

        # Test with fallback coordinate type
        result2 = route_many_to_many(
            osrm,
            locations;
            fallback_coordinate_type = TABLE_FALLBACK_COORDINATE_INPUT
        )

        @test result2.metrics isa Matrix{Float32}
        @test size(result2.metrics) == (3, 3)
    end

    @testset "Scale factor" begin
        # Test with scale factor
        result = route_many_to_many(
            osrm,
            locations;
            scale_factor = 1.5
        )

        @test result.metrics isa Matrix{Float32}
        @test size(result.metrics) == (3, 3)
    end

    @testset "Combined parameters" begin
        # Test with multiple parameters combined
        result = route_many_to_many(
            osrm,
            locations;
            origin_indices = [1, 2],
            destination_indices = [2, 3],
            annotation = TABLE_ANNOTATIONS_DISTANCE,
            fallback_speed = 60.0,
            fallback_coordinate_type = TABLE_FALLBACK_COORDINATE_INPUT,
            scale_factor = 2.0
        )

        @test result.metric_type == :distance
        @test result.origin_indices == [1, 2]
        @test result.destination_indices == [2, 3]
        @test size(result.metrics) == (2, 2)
    end

    @testset "ManyToManyMetric struct" begin
        result = route_many_to_many(osrm, locations)

        # Test struct fields
        @test result.locations == locations
        @test result.origin_indices isa Vector{Int64}
        @test result.destination_indices isa Vector{Int64}
        @test result.metrics isa Matrix{Float32}
        @test result.metric_type isa Symbol
        @test result.metric_type in [:distance, :duration]
    end

    @testset "Matrix properties" begin
        result = route_many_to_many(osrm, locations)

        # Test matrix properties
        @test size(result.metrics) == (length(locations), length(locations))

        # Diagonal should be 0 or very small (distance/duration from location to itself)
        for i in 1:min(size(result.metrics)...)
            @test result.metrics[i, i] >= 0.0f0
        end

        # Matrix should be symmetric-ish for distance (not necessarily for duration with one-way roads)
        # But we can at least check that all values are non-negative
        for i in 1:size(result.metrics, 1)
            for j in 1:size(result.metrics, 2)
                @test result.metrics[i, j] >= 0.0f0
                @test !isnan(result.metrics[i, j])
                @test !isinf(result.metrics[i, j])
            end
        end
    end

    @testset "Edge cases" begin
        # Test with single location
        single_location = [locations[1]]
        result = route_many_to_many(osrm, single_location)

        @test length(result.locations) == 1
        @test size(result.metrics) == (1, 1)
        @test result.metrics[1, 1] >= 0.0f0

        # Test with two locations
        two_locations = [locations[1], locations[2]]
        result2 = route_many_to_many(osrm, two_locations)

        @test length(result2.locations) == 2
        @test size(result2.metrics) == (2, 2)
    end
end
