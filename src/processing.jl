using DelimitedFiles, CSV, DataFrames

function load_data_old(filepath::String)
    df = CSV.read(filepath, DataFrame; header=1)

    ncols = ncol(df)
    channels = Dict{String, Channel}()

    # Step through columns in pairs: (time, value)
    for i in 1:2:ncols
        time_col = df[!, i]
        val_col  = df[!, i+1]
        name     = string(names(df)[i+1])  # value column name

        # Drop missing/NaN rows
        mask = .!ismissing.(time_col) .& .!ismissing.(val_col)
        t = Float64.(time_col[mask])
        v = Float64.(val_col[mask])

        channels[name] = Channel(name, t, v)
    end

    return Dataset(channels)
end