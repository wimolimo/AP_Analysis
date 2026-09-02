
struct Channel
    name::String
    time::Vector{Float64}    # unix timestamps
    values::Vector{Float64}
end

struct Dataset
    channels::Dict{String, Channel}
end

struct SMPSData
    name::String
    time::Vector{DateTime}
    diameters::Vector{Float64}   # bin midpoints [nm]
    dNdlogDp::Matrix{Float64}  # (time × bins)
end

using CSV, DataFrames, Dates

function load_data(filepath::String, time_range::Union{Nothing,Tuple{DateTime,DateTime}}=nothing)
    first_line = strip(readline(filepath))
    
    if startswith(lowercase(first_line), "numberofheaderrows")
        return _load_custom_format(filepath, first_line, time_range)
    elseif startswith(lowercase(first_line), "number of header rows")
        return load_smps_format(filepath, first_line, time_range)
    elseif startswith(basename(filepath), "AP")
        return _load_AP_format(filepath, time_range)
    else
        return _load_normal_format(filepath, time_range)
    end
end

function _load_normal_format(filepath::String, time_range::Union{Nothing,Tuple{DateTime,DateTime}}=nothing)
    df = CSV.read(filepath, DataFrame)
    cols = names(df)
    
    channels = Dict{String, Channel}()
    i = 1
    while i < length(cols)
        time_col = cols[i]
        value_col = cols[i + 1]
        
        time_raw = Float64.(coalesce.(df[!, time_col], NaN))
        data_raw = Float64.(coalesce.(df[!, value_col], NaN))
        
        valid_time = .!isnan.(time_raw)
        time_vals = time_raw[valid_time]
        data_vals = data_raw[valid_time]
        
        # Apply time range filter
        mask = _filter_time_range(time_vals, time_range)
        time_vals = time_vals[mask]
        data_vals = data_vals[mask]
        
        chan_name = value_col
        channels[chan_name] = Channel(chan_name, time_vals, data_vals)
        i += 2
    end
    
    return Dataset(channels)
end

function _load_custom_format(filepath::String, first_line::AbstractString, time_range::Union{Nothing,Tuple{DateTime,DateTime}}=nothing)
    n_header = parse(Int, split(first_line, ":")[2] |> strip)
    
    lines = readlines(filepath)
    header_line = lines[n_header]
    col_names = strip.(split(header_line, ","))
    
    df = CSV.read(filepath, DataFrame;
        header = false,
        skipto = n_header + 1,
        missingstring = "NaN",
    )
    rename!(df, Symbol.(col_names))
    
    epoch = DateTime(1970, 1, 1)
    time_col = col_names[1]
    timestamps = DateTime.(df[!, time_col], dateformat"yyyy-mm-dd HH:MM:SS")
    time_ms = Float64[Dates.value(t - epoch) for t in timestamps]
    
    # Apply time range filter
    mask = _filter_time_range(time_ms, time_range)
    time_ms = time_ms[mask]
    
    channels = Dict{String, Channel}()
    for name in col_names[2:end]
        values = Float64.(coalesce.(df[!, name], NaN))[mask]
        channels[name] = Channel(name, time_ms, values)
    end
    
    return Dataset(channels)
end

function _load_AP_format(filepath::String, time_range::Union{Nothing,Tuple{DateTime,DateTime}}=nothing)
    df = CSV.read(filepath, DataFrame; header=1)
    
    epoch = DateTime(1970, 1, 1)
    time_col = names(df)[1]
    timestamps = DateTime.(df[!, time_col], dateformat"yyyy-mm-dd HH:MM:SS.sss")
    time_ms = Float64[Dates.value(t - epoch) for t in timestamps]

    # Apply time range filter
    mask = _filter_time_range(time_ms, time_range)
    time_ms = time_ms[mask]

    channels = Dict{String, Channel}()
    for name in names(df)[2:end]
        values = Float64.(coalesce.(df[!, name], NaN))[mask]
        channels[name] = Channel(name, time_ms, values)
    end

    return Dataset(channels)
end

function load_smps_format(filepath::String, first_line::AbstractString, time_range::Union{Nothing,Tuple{DateTime,DateTime}}=nothing)
    n_header = parse(Int, split(first_line, ":")[2] |> strip)

    lines_all = readlines(filepath)
    header_line = lines_all[n_header+1]
    col_names = strip.(split(header_line, ","))
    n_cols = length(col_names)

    df = CSV.read(filepath, DataFrame;
        header = false,
        skipto = n_header + 2,
        missingstring = "NaN",
        select = 1:n_cols,
    )
    rename!(df, Symbol.(col_names))

    epoch = DateTime(1970, 1, 1)
    raw_time = Float64.(coalesce.(df[!, col_names[1]], NaN))
    timestamps = [isnan(t) ? DateTime(0) : epoch + Second(round(Int, t)) for t in raw_time]

    # Apply time range filter
    mask = _filter_time_range_dt(timestamps, time_range)
    timestamps = timestamps[mask]

    bin_names = col_names[2:end]
    diameters = parse.(Float64, bin_names)

    # Build filtered (ntime × nbins) matrix
    rows = findall(mask)
    mat = Matrix{Float64}(undef, length(rows), length(bin_names))
    for (j, name) in enumerate(bin_names)
        col = df[!, name]
        for (ki, k) in enumerate(rows)
            val = col[k]
            mat[ki, j] = ismissing(val) ? NaN : Float64(val)
        end
    end

    return SMPSData("SMPS", timestamps, diameters, mat)
end


function _filter_time_range(time_ms::Vector{Float64}, time_range::Union{Nothing,Tuple{DateTime,DateTime}})
    time_range === nothing && return trues(length(time_ms))
    epoch = DateTime(1970, 1, 1)
    t_lo = Float64(Dates.value(time_range[1] - epoch))
    t_hi = Float64(Dates.value(time_range[2] - epoch))
    return t_lo .<= time_ms .<= t_hi
end

function _filter_time_range_dt(timestamps::Vector{DateTime}, time_range::Union{Nothing,Tuple{DateTime,DateTime}})
    time_range === nothing && return trues(length(timestamps))
    return time_range[1] .<= timestamps .<= time_range[2]
end

# Convenience: dataset.temp or dataset["temp"]
Base.getindex(d::Dataset, key::String) = d.channels[key]

function parse_cloud_log(filepath::String)
    content = read(filepath, String)
    stage_numbers = [m[1] for m in eachmatch(r"\*{12,}(\d+\.\d+)\*{12,}", content)]
    stage_splits = split(content, r"\*{12,}\d+\.\d+\*{12,}")

    results = []
    for (idx, stage_number) in enumerate(stage_numbers)
        block = stage_splits[idx + 1]

        type_m = match(r"Type:\s*(.+)", block)
        stage_type = type_m !== nothing ? strip(String(type_m[1])) : ""

        desc_m = match(r"Description:\s*(.*)", block)
        description = desc_m !== nothing ? strip(String(desc_m[1])) : ""

        comm_m = match(r"Comments:\s*(.*)", block)
        comments = comm_m !== nothing ? strip(String(comm_m[1])) : ""

        details = [strip(String(m.match)) for m in eachmatch(r"\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} .+", block)]

        time_m = match(r"(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})", block)
        stage_time = time_m !== nothing ? DateTime(time_m[1], dateformat"yyyy-mm-dd HH:MM:SS") : nothing
        
        push!(results, Dict(
            "stage"       => String(stage_number),
            "time"        => stage_time,
            "type"        => stage_type,
            "description" => description,
            "comments"    => comments,
            "details"     => details,
        ))
    end
    return results
end