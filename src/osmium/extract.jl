"""
    osmium_extract(input_file; bbox=nothing, config_file=nothing, polygon_file=nothing, output_file=nothing, output_directory=nothing, ...)

Extract OSM data from an input file using a bounding box, config file, or polygon file.

# Arguments
**Required Arguments**
- `input_file`: Path to the input OSM file

**Extraction Method (provide exactly one)**
- `bbox`: Named tuple with `southwest` and `northeast`, each containing `lat` and `lon` fields
- `config_file`: Path to config file (alternative to bbox)
- `polygon_file`: Path to polygon file (alternative to bbox)

**Output Options (provide at least one)**
- `output_file`: Path where the extracted OSM file will be saved
- `output_directory`: Output directory (used with config file)

**Strategy Options**
- `strategy`: Extract strategy (default: "complete_ways")
- `strategy_option`: Set strategy option (can be called multiple times)
- `set_bounds`: Sets bounds (bounding box) in header (default: false)
- `clean`: Clean attributes (version, changeset, timestamp, uid, user) - can be a string or array

**History Options**
- `with_history`: Input and output files are history files (default: false)

**Input Options**
- `input_format`: Format of input file (e.g., "pbf", "osm", "xml")

**Output Options**
- `output_format`: Format of output file (e.g., "pbf", "osm", "xml")
- `fsync`: Call fsync after writing file (default: false)
- `generator`: Generator setting for file header
- `output_header`: Add output header
- `overwrite`: Allow existing output file to be overwritten (default: false)

**Common Options**
- `verbose`: Set verbose mode (default: false)
- `progress`: Display progress bar (default: false)
- `no_progress`: Suppress display of progress bar (default: false)

# Examples
```julia
osmium_extract("path/to/input.osm.pbf")
osmium_extract("path/to/input.osm.pbf", bbox = box)
osmium_extract("path/to/input.osm.pbf", config_file = "path/to/config.json")
osmium_extract("path/to/input.osm.pbf", polygon_file = "path/to/polygon.geojson")
osmium_extract("path/to/input.osm.pbf", output_file = "path/to/output.osm.pbf")
osmium_extract("path/to/input.osm.pbf", output_directory = "path/to/output")
```
"""
function osmium_extract(
        input_file;
        # Extraction method
        bbox::NamedTuple{(:southwest, :northeast), Tuple{NamedTuple{(:lat, :lon), Tuple{Float64, Float64}}, NamedTuple{(:lat, :lon), Tuple{Float64, Float64}}}} = nothing,
        config_file::Union{String, Nothing} = nothing,
        polygon_file::Union{String, Nothing} = nothing,
        # Output options
        output_file::Union{String, Nothing} = nothing,
        output_directory::Union{String, Nothing} = nothing,
        # Strategy options
        strategy::Union{String, Nothing} = "complete_ways",
        strategy_option::Union{String, Nothing} = nothing,
        set_bounds::Bool = false,
        clean::Union{String, Nothing} = nothing,
        # History options
        with_history::Bool = false,
        # Input options
        input_format::Union{String, Nothing} = nothing,
        # Output options
        output_format::Union{String, Nothing} = nothing,
        fsync = false,
        generator::Union{String, Nothing} = nothing,
        output_header::Union{String, Nothing} = nothing,
        overwrite::Bool = false,
        # Common options
        verbose::Bool = false,
        progress::Bool = false,
        no_progress::Bool = false,
    )
    # Validate that exactly one extraction method is provided
    extraction_methods = [bbox !== nothing, config_file !== nothing, polygon_file !== nothing]
    if count(extraction_methods) != 1
        error("Exactly one of bbox, config_file, or polygon_file must be provided")
    end

    # Validate that at least one output option is provided
    if output_file === nothing && output_directory === nothing
        error("At least one of output_file or output_directory must be provided")
    end

    cmd = `$(osmium_jll.osmium()) extract`

    # Extraction method
    if bbox !== nothing
        bbox_string = "$(bbox.southwest.lon),$(bbox.southwest.lat),$(bbox.northeast.lon),$(bbox.northeast.lat)"
        cmd = `$cmd -b $bbox_string`
    elseif config_file !== nothing
        cmd = `$cmd -c $config_file`
    elseif polygon_file !== nothing
        cmd = `$cmd -p $polygon_file`
    end

    # Strategy options
    cmd = `$cmd -s $strategy`
    if strategy_option !== nothing
        if strategy_option isa AbstractVector
            for opt in strategy_option
                cmd = `$cmd -S $opt`
            end
        else
            cmd = `$cmd -S $strategy_option`
        end
    end
    if set_bounds
        cmd = `$cmd --set-bounds`
    end
    if clean !== nothing
        if clean isa AbstractVector
            cmd = `$cmd --clean $(join(clean, ","))`
        else
            cmd = `$cmd --clean $clean`
        end
    end

    # History options
    if with_history
        cmd = `$cmd -H`
    end

    # Input options
    if input_format !== nothing
        cmd = `$cmd -F $input_format`
    end

    # Output options
    if output_format !== nothing
        cmd = `$cmd -f $output_format`
    end
    if fsync
        cmd = `$cmd --fsync`
    end
    if generator !== nothing
        cmd = `$cmd --generator $generator`
    end
    if output_file !== nothing
        cmd = `$cmd -o $output_file`
    end
    if output_directory !== nothing
        cmd = `$cmd -d $output_directory`
    end
    if overwrite
        cmd = `$cmd -O`
    end
    if output_header !== nothing
        cmd = `$cmd --output-header $output_header`
    end

    # Common options
    if verbose
        cmd = `$cmd -v`
    end
    if progress
        cmd = `$cmd --progress`
    end
    if no_progress
        cmd = `$cmd --no-progress`
    end

    # Add input file
    cmd = `$cmd $input_file`

    return run(cmd)
end
