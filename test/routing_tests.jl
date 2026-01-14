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
        # Build OSRM graph if it doesn't exist or is incomplete
        osrm_base_path = joinpath(TEST_DATA_DIR, "hamburg-latest.osrm")

        # Check for all required OSRM files
        required_files = [
            "$osrm_base_path.partition",
            "$osrm_base_path.cells",
            "$osrm_base_path.cell_metrics",
            "$osrm_base_path.mldgr",
        ]

        graph_complete = all(isfile, required_files)

        if !graph_complete
            @info "Building OSRM graph for tests..."

            # Remove any incomplete graph files to ensure clean regeneration
            # Remove all known OSRM file extensions
            osrm_extensions = [
                ".partition", ".cells", ".cell_metrics", ".mldgr",
                ".ebg", ".ebg_nodes", ".enw", ".cnbg", ".hsgr",
                ".ramIndex", ".properties", ".maneuver_overrides",
                ".datasource_names", ".fileIndex", ".geometry",
                ".names", ".timestamp", ".edges", ".nodes",
            ]

            for ext in osrm_extensions
                file = "$osrm_base_path$ext"
                if isfile(file)
                    rm(file; force = true)
                end
            end

            create_graph_files(HAMBURG_OSM_PATH; profile = PROFILE_CAR)

            # Verify all files were created
            for file in required_files
                if !isfile(file)
                    error("Required OSRM file not created: $file")
                end
            end
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

        # Diagonal should be exactly 0 (duration from location to itself)
        for i in 1:3
            @test result.metrics[i, i] == 0.0f0
        end

        # All values should be non-negative, finite, and not NaN
        for i in 1:3
            for j in 1:3
                @test result.metrics[i, j] >= 0.0f0
                @test !isnan(result.metrics[i, j])
                @test !isinf(result.metrics[i, j])
            end
        end

        # Check exact values for known routes in Hamburg test dataset
        # Airport (index 2) to Port (index 3): 1696.0 seconds
        @test result.metrics[2, 3] ≈ 1696.0f0 atol = 0.1f0
        # Port (index 3) to Airport (index 2): 1738.8 seconds
        @test result.metrics[3, 2] ≈ 1738.8f0 atol = 0.1f0
        # City center (index 1) routes
        @test result.metrics[1, 1] == 0.0f0  # City center to itself
        @test result.metrics[1, 2] ≈ 1132.2f0 atol = 0.1f0  # City center to Airport
        @test result.metrics[1, 3] ≈ 778.9f0 atol = 0.1f0  # City center to Port
        @test result.metrics[2, 1] ≈ 1108.9f0 atol = 0.1f0  # Airport to City center
        @test result.metrics[3, 1] ≈ 908.0f0 atol = 0.1f0  # Port to City center
    end

    @testset "Distance annotation" begin
        # Test with distance annotation
        result = route_many_to_many(osrm, locations; annotation = TABLE_ANNOTATIONS_DISTANCE)

        @test result.metric_type == :distance
        @test result.metrics isa Matrix{Float32}
        @test size(result.metrics) == (3, 3)

        # Diagonal should be exactly 0 (distance from location to itself)
        for i in 1:3
            @test result.metrics[i, i] == 0.0f0
        end

        # Distance should be non-negative, finite, and not NaN
        for i in 1:size(result.metrics, 1)
            for j in 1:size(result.metrics, 2)
                @test result.metrics[i, j] >= 0.0f0
                @test !isnan(result.metrics[i, j])
                @test !isinf(result.metrics[i, j])
            end
        end

        # If a route exists, it should be within reasonable bounds (meters)
        # Hamburg city center to airport is roughly 10-15 km
        # Check that non-zero values are reasonable (between 1m and 1000km)
        for i in 1:3
            for j in 1:3
                if result.metrics[i, j] > 0.0f0
                    @test result.metrics[i, j] >= 1.0f0  # At least 1 meter
                    @test result.metrics[i, j] <= 1_000_000.0f0  # At most 1000 km
                end
            end
        end

        # Check exact values for known routes in Hamburg test dataset
        # Airport (index 2) to Port (index 3): 17399.9 meters
        @test result.metrics[2, 3] ≈ 17399.9f0 atol = 0.1f0
        # Port (index 3) to Airport (index 2): 18240.3 meters
        @test result.metrics[3, 2] ≈ 18240.3f0 atol = 0.1f0
        # City center (index 1) routes
        @test result.metrics[1, 1] == 0.0f0  # City center to itself
        @test result.metrics[1, 2] ≈ 11266.6f0 atol = 0.1f0  # City center to Airport
        @test result.metrics[1, 3] ≈ 7861.9f0 atol = 0.1f0  # City center to Port
        @test result.metrics[2, 1] ≈ 10712.1f0 atol = 0.1f0  # Airport to City center
        @test result.metrics[3, 1] ≈ 9129.3f0 atol = 0.1f0  # Port to City center
    end

    @testset "Duration annotation" begin
        # Test with duration annotation (default)
        result = route_many_to_many(osrm, locations; annotation = TABLE_ANNOTATIONS_DURATION)

        @test result.metric_type == :duration
        @test result.metrics isa Matrix{Float32}
        @test size(result.metrics) == (3, 3)

        # Diagonal should be exactly 0 (duration from location to itself)
        for i in 1:3
            @test result.metrics[i, i] == 0.0f0
        end

        # Duration should be non-negative, finite, and not NaN
        for i in 1:size(result.metrics, 1)
            for j in 1:size(result.metrics, 2)
                @test result.metrics[i, j] >= 0.0f0
                @test !isnan(result.metrics[i, j])
                @test !isinf(result.metrics[i, j])
            end
        end

        # If a route exists, duration should be within reasonable bounds (seconds)
        # Hamburg city center to airport is roughly 15-30 minutes by car
        # Check that non-zero values are reasonable (between 1s and 24 hours)
        for i in 1:3
            for j in 1:3
                if result.metrics[i, j] > 0.0f0
                    @test result.metrics[i, j] >= 1.0f0  # At least 1 second
                    @test result.metrics[i, j] <= 86400.0f0  # At most 24 hours (86400 seconds)
                end
            end
        end

        # Check exact values for known routes in Hamburg test dataset
        # Airport (index 2) to Port (index 3): 1696.0 seconds
        @test result.metrics[2, 3] ≈ 1696.0f0 atol = 0.1f0
        # Port (index 3) to Airport (index 2): 1738.8 seconds
        @test result.metrics[3, 2] ≈ 1738.8f0 atol = 0.1f0
        # City center (index 1) routes
        @test result.metrics[1, 1] == 0.0f0  # City center to itself
        @test result.metrics[1, 2] ≈ 1132.2f0 atol = 0.1f0  # City center to Airport
        @test result.metrics[1, 3] ≈ 778.9f0 atol = 0.1f0  # City center to Port
        @test result.metrics[2, 1] ≈ 1108.9f0 atol = 0.1f0  # Airport to City center
        @test result.metrics[3, 1] ≈ 908.0f0 atol = 0.1f0  # Port to City center
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
        # result.metrics[2, 1] should be from location 2 to location 2 (same location)
        # result.metrics[2, 2] should be from location 2 to location 3
        @test result.metrics[1, 1] ≈ 1132.2f0 atol = 0.1f0  # 1 -> 2 (City center to Airport)
        @test result.metrics[1, 2] ≈ 778.9f0 atol = 0.1f0  # 1 -> 3 (City center to Port)
        @test result.metrics[2, 1] == 0.0f0  # 2 -> 2 (should be exactly 0, same location)
        # Check exact values: Airport (index 2) to Port (index 3)
        # Duration: 1696.0 seconds, Distance: 17399.9 meters
        if result.metric_type == :duration
            @test result.metrics[2, 2] ≈ 1696.0f0 atol = 0.1f0  # 2 -> 3
        elseif result.metric_type == :distance
            @test result.metrics[2, 2] ≈ 17399.9f0 atol = 0.1f0  # 2 -> 3
        else
            error("Unknown metric type: $(result.metric_type)")
        end

        # All values should be finite and not NaN
        for i in 1:2
            for j in 1:2
                @test !isnan(result.metrics[i, j])
                @test !isinf(result.metrics[i, j])
            end
        end
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

        # Distance/duration from location 1 to itself should be exactly 0
        @test result.metrics[1, 1] == 0.0f0

        # All values should be non-negative, finite, and not NaN
        for j in 1:3
            @test result.metrics[1, j] >= 0.0f0
            @test !isnan(result.metrics[1, j])
            @test !isinf(result.metrics[1, j])
        end

        # Check exact values: routes from city center (index 1)
        @test result.metrics[1, 1] == 0.0f0  # 1 -> 1 (City center to itself)
        @test result.metrics[1, 2] ≈ 1132.2f0 atol = 0.1f0  # 1 -> 2 (City center to Airport)
        @test result.metrics[1, 3] ≈ 778.9f0 atol = 0.1f0  # 1 -> 3 (City center to Port)
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

        # Distance/duration from location 2 to itself should be exactly 0
        @test result.metrics[2, 1] == 0.0f0

        # All values should be non-negative, finite, and not NaN
        for i in 1:3
            @test result.metrics[i, 1] >= 0.0f0
            @test !isnan(result.metrics[i, 1])
            @test !isinf(result.metrics[i, 1])
        end

        # Check exact values for routes to airport (index 2)
        @test result.metrics[1, 1] ≈ 1132.2f0 atol = 0.1f0  # 1 -> 2 (City center to Airport)
        @test result.metrics[2, 1] == 0.0f0  # 2 -> 2 (same location)
        # Port (index 3) to Airport (index 2): 1738.8 seconds
        @test result.metrics[3, 1] ≈ 1738.8f0 atol = 0.1f0  # 3 -> 2
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
        # Get baseline values without scale factor
        baseline = route_many_to_many(osrm, locations)

        # Test with scale factor
        scale = 2.0f0
        result = route_many_to_many(
            osrm,
            locations;
            scale_factor = scale
        )

        @test result.metrics isa Matrix{Float32}
        @test size(result.metrics) == (3, 3)

        # Diagonal should still be 0 (scale factor doesn't affect same-location routes)
        for i in 1:3
            @test result.metrics[i, i] == 0.0f0
        end

        # Non-zero values should be scaled by the scale factor
        # Allow small floating point differences
        for i in 1:3
            for j in 1:3
                if baseline.metrics[i, j] > 0.0f0
                    expected = baseline.metrics[i, j] * scale
                    @test abs(result.metrics[i, j] - expected) < 0.1f0
                else
                    @test result.metrics[i, j] == 0.0f0
                end
            end
        end
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

        # Diagonal should be exactly 0 (distance/duration from location to itself)
        for i in 1:min(size(result.metrics)...)
            @test result.metrics[i, i] == 0.0f0
        end

        # All values should be non-negative, finite, and not NaN
        for i in 1:size(result.metrics, 1)
            for j in 1:size(result.metrics, 2)
                @test result.metrics[i, j] >= 0.0f0
                @test !isnan(result.metrics[i, j])
                @test !isinf(result.metrics[i, j])
            end
        end

        # For duration, check that values are in reasonable range (seconds)
        # Duration should be between 0 and 24 hours for any route
        for i in 1:size(result.metrics, 1)
            for j in 1:size(result.metrics, 2)
                if result.metrics[i, j] > 0.0f0
                    @test result.metrics[i, j] >= 1.0f0  # At least 1 second
                    @test result.metrics[i, j] <= 86400.0f0  # At most 24 hours
                end
            end
        end
    end

    @testset "Edge cases" begin
        # Test with single location
        single_location = [locations[1]]
        result = route_many_to_many(osrm, single_location)

        @test length(result.locations) == 1
        @test size(result.metrics) == (1, 1)
        @test result.metrics[1, 1] == 0.0f0  # Exactly 0 for same location
        @test !isnan(result.metrics[1, 1])
        @test !isinf(result.metrics[1, 1])

        # Test with two locations
        two_locations = [locations[1], locations[2]]
        result2 = route_many_to_many(osrm, two_locations)

        @test length(result2.locations) == 2
        @test size(result2.metrics) == (2, 2)

        # Diagonal should be exactly 0
        @test result2.metrics[1, 1] == 0.0f0
        @test result2.metrics[2, 2] == 0.0f0

        # All values should be non-negative, finite, and not NaN
        for i in 1:2
            for j in 1:2
                @test result2.metrics[i, j] >= 0.0f0
                @test !isnan(result2.metrics[i, j])
                @test !isinf(result2.metrics[i, j])
            end
        end
    end
end
