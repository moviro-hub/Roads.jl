using Test
using Roads

# Test data paths
const TEST_DATA_DIR = joinpath(@__DIR__, "data")
const HAMBURG_OSM_PATH = joinpath(TEST_DATA_DIR, "hamburg-latest.osm.pbf")

# Create a small subset for faster network tests
const _subset_cache = Ref{Union{String, Nothing}}(nothing)

"""
Get a small subset of Hamburg data for network tests.
This subset is cached to avoid recreating it for each test.
"""
function get_test_subset()::String
    if _subset_cache[] === nothing
        subset_path = joinpath(TEST_DATA_DIR, "hamburg-subset-network-test.osm.pbf")

        if !isfile(subset_path)
            # Create a larger bounding box around Hamburg city center to ensure enough road data
            # This ensures we have enough road network for graph building
            bbox = Roads.BBox(53.54f0, 9.98f0, 53.57f0, 10.01f0)
            Roads.subset_file(
                HAMBURG_OSM_PATH;
                bbox = bbox,
                output_file = subset_path,
                overwrite = true,
                no_progress = true,
                strategy = "complete_ways"
            )
        end

        _subset_cache[] = subset_path
    end
    return _subset_cache[]
end

const TEST_SUBSET_PATH = get_test_subset()

@testset "create_graph_files" begin
    @testset "Basic graph creation" begin
        mktempdir() do tmpdir
            # Copy test subset to temp directory with specific name
            temp_osm_path = joinpath(tmpdir, "hamburg_test.osm.pbf")
            cp(TEST_SUBSET_PATH, temp_osm_path)
            osrm_base_path = joinpath(tmpdir, "hamburg_test.osrm")

            # Test basic graph creation with default parameters using subset data
            create_graph_files(temp_osm_path)

            # Check that partition file exists (indicates graph was built)
            @test isfile("$osrm_base_path.partition")

            # Check that other key files exist (created by customize step)
            @test isfile("$osrm_base_path.cells")
            @test isfile("$osrm_base_path.cell_metrics")
            @test isfile("$osrm_base_path.mldgr")
        end
    end

    @testset "Different profiles" begin
        mktempdir() do tmpdir
            # Test with PROFILE_CAR (default)
            temp_osm_car = joinpath(tmpdir, "hamburg_car.osm.pbf")
            cp(TEST_SUBSET_PATH, temp_osm_car)
            osrm_base_car = joinpath(tmpdir, "hamburg_car.osrm")
            create_graph_files(temp_osm_car; profile = PROFILE_CAR)
            @test isfile("$osrm_base_car.partition")

            # Test with PROFILE_BICYCLE
            temp_osm_bicycle = joinpath(tmpdir, "hamburg_bicycle.osm.pbf")
            cp(TEST_SUBSET_PATH, temp_osm_bicycle)
            osrm_base_bicycle = joinpath(tmpdir, "hamburg_bicycle.osrm")
            create_graph_files(temp_osm_bicycle; profile = PROFILE_BICYCLE)
            @test isfile("$osrm_base_bicycle.partition")
        end
    end

    @testset "Verbosity levels" begin
        mktempdir() do tmpdir
            # Test with VERBOSITY_NONE
            temp_osm_none = joinpath(tmpdir, "hamburg_none.osm.pbf")
            cp(TEST_SUBSET_PATH, temp_osm_none)
            osrm_base_none = joinpath(tmpdir, "hamburg_none.osrm")
            create_graph_files(temp_osm_none; verbosity = VERBOSITY_NONE)
            @test isfile("$osrm_base_none.partition")
        end
    end

    @testset "Thread parameters" begin
        mktempdir() do tmpdir
            # Test with multiple threads
            temp_osm_threads = joinpath(tmpdir, "hamburg_threads.osm.pbf")
            cp(TEST_SUBSET_PATH, temp_osm_threads)
            osrm_base_threads = joinpath(tmpdir, "hamburg_threads.osrm")
            create_graph_files(temp_osm_threads; threads = 2)
            @test isfile("$osrm_base_threads.partition")
        end
    end

    @testset "Extract parameters" begin
        mktempdir() do tmpdir
            temp_osm = joinpath(tmpdir, "hamburg_extract.osm.pbf")
            cp(TEST_SUBSET_PATH, temp_osm)
            osrm_base = joinpath(tmpdir, "hamburg_extract.osrm")

            # Test with extract parameters (note: data_version may not be supported by all OSRM versions)
            # Test with other extract parameters that are known to work
            create_graph_files(
                temp_osm;
                with_osm_metadata = false,
                parse_conditional_restrictions = false,
                small_component_size = 1000
            )
            @test isfile("$osrm_base.partition")
        end
    end

    @testset "Partition parameters" begin
        mktempdir() do tmpdir
            temp_osm = joinpath(tmpdir, "hamburg_partition.osm.pbf")
            cp(TEST_SUBSET_PATH, temp_osm)
            osrm_base = joinpath(tmpdir, "hamburg_partition.osrm")

            # Test with custom partition parameters
            create_graph_files(
                temp_osm;
                balance = 1.5,
                boundary = 0.3,
                optimizing_cuts = 5,
                max_cell_sizes = [64, 2048, 32768, 1048576]
            )
            @test isfile("$osrm_base.partition")
        end
    end

    @testset "Customize parameters" begin
        mktempdir() do tmpdir
            temp_osm = joinpath(tmpdir, "hamburg_customize.osm.pbf")
            cp(TEST_SUBSET_PATH, temp_osm)
            osrm_base = joinpath(tmpdir, "hamburg_customize.osrm")

            # Test with customize parameters (empty files are fine for testing)
            create_graph_files(
                temp_osm;
                segment_speed_file = String[],
                turn_penalty_file = String[],
                edge_weight_updates_over_factor = 0.5,
                parse_conditionals_from_now = 0,
                time_zone_file = ""
            )
            @test isfile("$osrm_base.partition")
        end
    end

    @testset "Combined parameters" begin
        mktempdir() do tmpdir
            temp_osm = joinpath(tmpdir, "hamburg_combined.osm.pbf")
            cp(TEST_SUBSET_PATH, temp_osm)
            osrm_base = joinpath(tmpdir, "hamburg_combined.osrm")

            # Test with multiple parameters combined (without data_version which may not be supported)
            create_graph_files(
                temp_osm;
                verbosity = VERBOSITY_INFO,
                threads = 1,
                profile = PROFILE_CAR,
                small_component_size = 2000,
                balance = 1.3,
                boundary = 0.2,
                optimizing_cuts = 8
            )
            @test isfile("$osrm_base.partition")
            @test isfile("$osrm_base.cells")
        end
    end

    @testset "Graph file verification" begin
        mktempdir() do tmpdir
            temp_osm = joinpath(tmpdir, "hamburg_verify.osm.pbf")
            cp(TEST_SUBSET_PATH, temp_osm)
            osrm_base = joinpath(tmpdir, "hamburg_verify.osrm")

            create_graph_files(temp_osm)

            # Verify key files exist
            @test isfile("$osrm_base.partition")
            @test isfile("$osrm_base.cells")
            @test isfile("$osrm_base.cell_metrics")
            @test isfile("$osrm_base.mldgr")
            @test isfile("$osrm_base.enw")
            @test isfile("$osrm_base.cnbg")
            @test isfile("$osrm_base.ebg")

            # Verify files have content
            @test filesize("$osrm_base.partition") > 0
            @test filesize("$osrm_base.cells") > 0
        end
    end

    @testset "Re-building graph" begin
        mktempdir() do tmpdir
            temp_osm = joinpath(tmpdir, "hamburg_rebuild.osm.pbf")
            cp(TEST_SUBSET_PATH, temp_osm)
            osrm_base = joinpath(tmpdir, "hamburg_rebuild.osrm")

            # Build graph first time
            create_graph_files(temp_osm)
            @test isfile("$osrm_base.partition")
            first_partition_size = filesize("$osrm_base.partition")

            # Re-build graph (should overwrite)
            create_graph_files(temp_osm)
            @test isfile("$osrm_base.partition")
            second_partition_size = filesize("$osrm_base.partition")

            # Sizes should be the same (same input data)
            @test first_partition_size == second_partition_size
        end
    end

    @testset "Input validation" begin
        mktempdir() do tmpdir
            # Test with non-existent input file - should throw an error
            try
                create_graph_files("/nonexistent/file.osm.pbf")
                @test false  # Should not reach here
            catch e
                # Expected - should be some kind of error
                @test e isa Exception
            end
        end
    end
end
