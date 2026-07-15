using Interpolations

function resample(ch::Channel, new_times::Vector{Float64})
    itp = linear_interpolation(ch.time, ch.values, extrapolation_bc=NaN)
    return Channel(ch.name, new_times, itp.(new_times))
end