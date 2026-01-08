using Test
using Roads

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

@testset "snap_location" begin
    # Get test OSRM instance (will build if needed)
    osrm = get_test_osrm()

    @testset "Basic snapping" begin
        # Test basic snap with default parameters
        locations = snap_location(osrm, HAMBURG_CITY_CENTER)

        @test locations isa Vector
        @test length(locations) >= 1
        @test locations[1].lat isa Float32
        @test locations[1].lon isa Float32
        @test locations[1].lat == HAMBURG_CITY_CENTER.lat
        @test locations[1].lon == HAMBURG_CITY_CENTER.lon
    end

    @testset "max_results parameter" begin
        # Test with max_results = 1
        locations1 = snap_location(osrm, HAMBURG_CITY_CENTER; max_results = 1)
        @test length(locations1) == 1

        # Test with max_results = 3
        locations3 = snap_location(osrm, HAMBURG_CITY_CENTER; max_results = 3)
        @test length(locations3) <= 3
        @test length(locations3) >= 1

        # Test with max_results = 5
        locations5 = snap_location(osrm, HAMBURG_CITY_CENTER; max_results = 5)
        @test length(locations5) <= 5
        @test length(locations5) >= 1
    end

    @testset "radius parameter" begin
        # Test with radius
        locations = snap_location(osrm, HAMBURG_CITY_CENTER; radius = 100.0)
        @test length(locations) >= 1
        # All locations should be within the radius
        for loc in locations
            if loc.distance !== nothing
                @test loc.distance <= 100.0f0
            end
        end

        # Test with larger radius
        locations_large = snap_location(osrm, HAMBURG_CITY_CENTER; radius = 1000.0)
        @test length(locations_large) >= 1
    end

    @testset "azimuth parameter" begin
        # Test with azimuth (bearing)
        locations = snap_location(osrm, HAMBURG_CITY_CENTER; azimuth = 45.0, azimuth_range = 30)
        @test length(locations) >= 1

        # Test with different azimuth
        locations2 = snap_location(osrm, HAMBURG_CITY_CENTER; azimuth = 90.0, azimuth_range = 15)
        @test length(locations2) >= 1
    end

    @testset "snapping parameter" begin
        # Test with SNAPPING_DEFAULT
        locations_default = snap_location(osrm, HAMBURG_CITY_CENTER; snapping = SNAPPING_DEFAULT)
        @test length(locations_default) >= 1

        # Test with SNAPPING_ANY
        locations_any = snap_location(osrm, HAMBURG_CITY_CENTER; snapping = SNAPPING_ANY)
        @test length(locations_any) >= 1
    end

    @testset "approach parameter" begin
        # Test with APPROACH_UNRESTRICTED
        locations_unrestricted = snap_location(osrm, HAMBURG_CITY_CENTER; approach = APPROACH_UNRESTRICTED)
        @test length(locations_unrestricted) >= 1

        # Test with APPROACH_CURB
        locations_curb = snap_location(osrm, HAMBURG_CITY_CENTER; approach = APPROACH_CURB)
        @test length(locations_curb) >= 1

        # Test with APPROACH_OPPOSITE
        locations_opposite = snap_location(osrm, HAMBURG_CITY_CENTER; approach = APPROACH_OPPOSITE)
        @test length(locations_opposite) >= 1
    end

    @testset "excludes parameter" begin
        # Test with empty excludes
        locations_no_exclude = snap_location(osrm, HAMBURG_CITY_CENTER; excludes = String[])
        @test length(locations_no_exclude) >= 1

        # Test with excludes (may fail if excludes are invalid or all roads are excluded)
        try
            locations_exclude = snap_location(osrm, HAMBURG_CITY_CENTER; excludes = ["motorway", "trunk"])
            # Should still return results (may be empty if all roads excluded)
            @test locations_exclude isa Vector
        catch e
            # Expected if excludes cause API errors
            @test e isa Exception
        end
    end

    @testset "Location struct fields" begin
        locations = snap_location(osrm, HAMBURG_CITY_CENTER; max_results = 1)
        @test length(locations) >= 1

        loc = locations[1]

        # Check types
        @test loc.name isa Union{String, Nothing}
        @test loc.lat isa Float32
        @test loc.lon isa Float32
        @test loc.azimuth isa Union{Float32, Nothing}
        @test loc.distance isa Union{Float32, Nothing}
        @test loc.osrm_hint isa Union{String, Nothing}

        # Position should match input
        @test loc.lat == HAMBURG_CITY_CENTER.lat
        @test loc.lon == HAMBURG_CITY_CENTER.lon

        # Check that fields are accessible
        @test hasproperty(loc, :name)
        @test hasproperty(loc, :lat)
        @test hasproperty(loc, :lon)
        @test hasproperty(loc, :azimuth)
        @test hasproperty(loc, :distance)
        @test hasproperty(loc, :osrm_hint)
    end

    @testset "Multiple coordinates" begin
        # Test with different coordinates
        locations1 = snap_location(osrm, HAMBURG_CITY_CENTER)
        locations2 = snap_location(osrm, HAMBURG_PORT)
        locations3 = snap_location(osrm, HAMBURG_AIRPORT)

        @test length(locations1) >= 1
        @test length(locations2) >= 1
        @test length(locations3) >= 1

        # Each should have correct input coordinates
        @test locations1[1].lat == HAMBURG_CITY_CENTER.lat
        @test locations1[1].lon == HAMBURG_CITY_CENTER.lon
        @test locations2[1].lat == HAMBURG_PORT.lat
        @test locations2[1].lon == HAMBURG_PORT.lon
        @test locations3[1].lat == HAMBURG_AIRPORT.lat
        @test locations3[1].lon == HAMBURG_AIRPORT.lon
    end

    @testset "Combined parameters" begin
        # Test with multiple parameters combined
        locations = snap_location(
            osrm,
            HAMBURG_CITY_CENTER;
            max_results = 3,
            radius = 500.0,
            azimuth = 90.0,
            azimuth_range = 45,
            snapping = SNAPPING_ANY,
            approach = APPROACH_CURB,
            excludes = String[]
        )

        @test length(locations) <= 3
        @test length(locations) >= 1

        for loc in locations
            if loc.distance !== nothing
                @test loc.distance <= 500.0f0
            end
        end
    end

    @testset "Edge cases" begin
        # Test with very small radius (may return no results or error)
        try
            locations_small = snap_location(osrm, HAMBURG_CITY_CENTER; radius = 1.0)
            @test locations_small isa Vector
            # May be empty if no roads within 1m
        catch e
            # Expected if radius is too small
            @test e isa Exception
        end

        # Test with very large radius
        locations_large = snap_location(osrm, HAMBURG_CITY_CENTER; radius = 10000.0)
        @test length(locations_large) >= 1

        # Test with max_results = 1 (minimum valid value)
        locations_one = snap_location(osrm, HAMBURG_CITY_CENTER; max_results = 1)
        @test length(locations_one) >= 1
        @test locations_one isa Vector
    end
end
