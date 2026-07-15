
struct Channel
    name::String
    time::Vector{Float64}    # unix timestamps
    values::Vector{Float64}
end

struct Dataset
    channels::Dict{String, Channel}
end

using CSV, DataFrames, Dates

function load_data(filepath::String)
    first_line = strip(readline(filepath))
    
    if startswith(lowercase(first_line), "numberofheaderrows")
        return _load_custom_format(filepath, first_line)
    else
        return _load_normal_format(filepath)
    end
end

function _load_normal_format(filepath::String)
    df = CSV.read(filepath, DataFrame)
    cols = names(df)
    
    channels = Dict{String, Channel}()
    i = 1
    while i < length(cols)
        time_col = cols[i]
        value_col = cols[i + 1]
        
        time_raw = Float64.(coalesce.(df[!, time_col], NaN))
        data_raw = Float64.(coalesce.(df[!, value_col], NaN))
        
        # Remove rows where time is NaN
        valid_time = .!isnan.(time_raw)
        time_vals = time_raw[valid_time]
        data_vals = data_raw[valid_time]
        
        chan_name = value_col
        channels[chan_name] = Channel(chan_name, time_vals, data_vals)
        i += 2
    end
    
    return Dataset(channels)
end

function _load_custom_format(filepath::String, first_line::AbstractString)
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
    
    # Parse datetime and convert to ms since epoch
    epoch = DateTime(1970, 1, 1)
    time_col = col_names[1]
    timestamps = DateTime.(df[!, time_col], dateformat"yyyy-mm-dd HH:MM:SS")
    time_ms = Float64[Dates.value(t - epoch) for t in timestamps]
    
    channels = Dict{String, Channel}()
    for name in col_names[2:end]
        values = Float64.(coalesce.(df[!, name], NaN))
        channels[name] = Channel(name, time_ms, values)
    end
    
    return Dataset(channels)
end

# Convenience: dataset.temp or dataset["temp"]
Base.getindex(d::Dataset, key::String) = d.channels[key]