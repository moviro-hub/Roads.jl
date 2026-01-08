using OpenSourceRoutingMachine: Verbosity, VERBOSITY_INFO
using OpenSourceRoutingMachine.Graph: Graph, Profile, PROFILE_CAR

"""
    create_graph_files(
        osm_path;
        profile=nothing,
        verbosity=VERBOSITY_INFO,
        threads=1,
        data_version="",
        with_osm_metadata=false,
        parse_conditional_restrictions=false,
        location_dependent_data=String[],
        disable_location_cache=false,
        dump_nbg_graph=false,
        small_component_size=1000,
        balance=1.2,
        boundary=0.25,
        optimizing_cuts=10,
        max_cell_sizes=[128, 4096, 65536, 2097152],
        segment_speed_file=String[],
        turn_penalty_file=String[],
        edge_weight_updates_over_factor=0.0,
        parse_conditionals_from_now=0,
        time_zone_file=""
    )

Creates MLD (Multi-Level Dijkstra) data from an OSM file using OpenSourceRoutingMachine.jl.

This function performs the three-step MLD graph building process:
1. **extract**: Extracts routing data from the OSM file using a routing profile
2. **partition**: Partitions the graph for multi-level Dijkstra
3. **customize**: Customizes the partitioned graph for routing queries

The output OSRM files are created in the same directory as the input OSM file, with the same base name but with `.osrm` extension.

# Arguments
- `osm_path::AbstractString`: Path to input OSM file (.osm, .osm.bz2, or .osm.pbf format)
- `verbosity::Verbosity`: Log verbosity level applied to all steps (default: `VERBOSITY_INFO`)
- `threads::Int`: Number of threads to use for all steps (default: `1`)
- `profile::Union{Profile, String}`: Routing profile to use (default: `PROFILE_CAR`). Can be a `Profile` enum (`PROFILE_CAR`, `PROFILE_BICYCLE`, `PROFILE_FOOT`) or a string path to a custom profile.lua file
- `data_version::String`: Data version string for extract step (default: `""`)
- `with_osm_metadata::Bool`: Use OSM metadata during parsing in extract step (default: `false`)
- `parse_conditional_restrictions::Bool`: Save conditional restrictions for contraction in extract step (default: `false`)
- `location_dependent_data::Vector{String}`: Vector of GeoJSON file paths for location-dependent data in extract step (default: `String[]`)
- `disable_location_cache::Bool`: Disable internal nodes locations cache in extract step (default: `false`)
- `dump_nbg_graph::Bool`: Dump raw node-based graph for debugging in extract step (default: `false`)
- `small_component_size::Int`: Size threshold for small components, applied to extract and partition steps (default: `1000`)
- `balance::Float64`: Balance for left and right side in single bisection for partition step (default: `1.2`)
- `boundary::Float64`: Percentage of embedded nodes to contract as sources and sinks for partition step (default: `0.25`)
- `optimizing_cuts::Int`: Number of cuts to use for optimizing a single bisection in partition step (default: `10`)
- `max_cell_sizes::Vector{Int}`: Maximum cell sizes starting from level 1 for partition step (default: `[128, 4096, 65536, 2097152]`)
- `segment_speed_file::Vector{String}`: Vector of lookup file paths containing nodeA, nodeB, speed data for customize step (default: `String[]`)
- `turn_penalty_file::Vector{String}`: Vector of lookup file paths containing from_, to_, via_nodes, and turn penalties for customize step (default: `String[]`)
- `edge_weight_updates_over_factor::Float64`: Factor for logging edge weight updates in customize step (default: `0.0`)
- `parse_conditionals_from_now::Int64`: UTC timestamp for evaluating conditional turn restrictions in customize step (default: `0`)
- `time_zone_file::String`: GeoJSON file containing time zone boundaries for conditional parsing in customize step (default: `""`)

# Returns
Returns `nothing`.

# Examples
```julia
# Basic usage with default profile
create_graph_files("data.osm.pbf")

# Using common arguments for all steps
using OpenSourceRoutingMachine: VERBOSITY_DEBUG
create_graph_files(
    "data.osm.pbf";
    verbosity = VERBOSITY_DEBUG,
    threads = 8
)

# With step-specific arguments
create_graph_files(
    "data.osm.pbf";
    verbosity = VERBOSITY_INFO,
    threads = 4,
    data_version = "v1.0",
    balance = 1.5,
    segment_speed_file = ["speeds.csv"]
)

```
"""
function create_graph_files(
        osm_path::AbstractString;
        # Common arguments
        verbosity::Verbosity = VERBOSITY_INFO,
        threads::Int = 1,
        # Extract-specific arguments
        profile::Union{Profile, String, Function} = PROFILE_CAR,
        data_version::String = "",
        with_osm_metadata::Bool = false,
        parse_conditional_restrictions::Bool = false,
        location_dependent_data::Vector{String} = String[],
        disable_location_cache::Bool = false,
        dump_nbg_graph::Bool = false,
        # Extract- and partition-specific arguments
        small_component_size::Int = 1000,
        # Partition-specific arguments
        balance::Float64 = 1.2,
        boundary::Float64 = 0.25,
        optimizing_cuts::Int = 10,
        max_cell_sizes::Vector{Int} = [128, 4096, 65536, 2097152],
        # Customize-specific arguments
        segment_speed_file::Vector{String} = String[],
        turn_penalty_file::Vector{String} = String[],
        edge_weight_updates_over_factor::Float64 = 0.0,
        parse_conditionals_from_now::Int64 = 0,
        time_zone_file::String = "",
    )

    # Derive osrm_base_path from osm_path
    # Remove all OSM extensions (.osm, .osm.bz2, .osm.pbf) and add .osrm
    osrm_base_path = osm_path
    while true
        base, ext = splitext(osrm_base_path)
        if ext in (".osm", ".bz2", ".pbf")
            osrm_base_path = base
        else
            break
        end
    end
    osrm_base_path = "$osrm_base_path.osrm"

    if profile isa Function
        profile = profile(osm_path)
        if !isa(profile, Profile) && !isa(profile, String)
            error("Profile function must return a Profile or String")
        end
    end

    # Step 1: Extract
    Graph.extract(
        osm_path;
        profile = profile,
        verbosity = verbosity,
        data_version = data_version,
        threads = threads,
        small_component_size = small_component_size,
        with_osm_metadata = with_osm_metadata,
        parse_conditional_restrictions = parse_conditional_restrictions,
        location_dependent_data = location_dependent_data,
        disable_location_cache = disable_location_cache,
        dump_nbg_graph = dump_nbg_graph,
    )

    # Step 2: Partition
    Graph.partition(
        osrm_base_path;
        verbosity = verbosity,
        threads = threads,
        balance = balance,
        boundary = boundary,
        optimizing_cuts = optimizing_cuts,
        small_component_size = small_component_size,
        max_cell_sizes = max_cell_sizes,
    )

    # Step 3: Customize
    Graph.customize(
        osrm_base_path;
        verbosity = verbosity,
        threads = threads,
        segment_speed_file = segment_speed_file,
        turn_penalty_file = turn_penalty_file,
        edge_weight_updates_over_factor = edge_weight_updates_over_factor,
        parse_conditionals_from_now = parse_conditionals_from_now,
        time_zone_file = time_zone_file,
    )

    return nothing
end
