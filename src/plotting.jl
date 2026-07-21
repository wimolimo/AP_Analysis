_normalize_channel_key(channel::Channel) = channel.name
_normalize_channel_key(channel::AbstractString) = String(channel)
_normalize_channel_key(channel::Symbol) = String(channel)

function _channel_datetimes(ch::Channel)
    epoch = DateTime(1970, 1, 1)
    return [isnan(t) ? DateTime(0) : epoch + Millisecond(round(Int, t)) for t in ch.time]
end

function _present(fig; interactive::Bool=false)
    if interactive
        GLMakie.closeall()
        screen = display(GLMakie.Screen(), fig)
        wait(screen)
    else
        display(fig)
    end
    return nothing
end

function _resolve_channels(data::Dataset, requested_channels)
    if requested_channels === nothing || (isa(requested_channels, AbstractVector) && isempty(requested_channels))
        names = sort!(collect(keys(data.channels)))
        return [data.channels[name] for name in names]
    end
    requested_channels isa AbstractVector || throw(ArgumentError("channels must be a vector of channel names"))
    return [requested isa Channel ? requested : data.channels[_normalize_channel_key(requested)] for requested in requested_channels]
end

function _pick_colors(n::Int)
    palette = PAPER_LINE_COLORS
    np = length(palette)
    if n >= np
        return [palette[mod1(i, np)] for i in 1:n]
    end
    indices = round.(Int, range(1, np, length=n))
    return [palette[i] for i in indices]
end

function _auto_ylims!(backend, ax, xlims)
    xl = (Dates.datetime2unix(xlims[1]) * 1000, Dates.datetime2unix(xlims[2]) * 1000)
    ymin, ymax = Inf, -Inf
    for plot in ax.scene.plots
        if hasproperty(plot, :input_args) && length(plot.input_args) >= 2
            xs = plot.input_args[1][]
            ys = plot.input_args[2][]
            for (x, y) in zip(xs, ys)
                xval = x isa DateTime ? Dates.datetime2unix(x) * 1000 : Float64(x)
                if xl[1] <= xval <= xl[2] && isfinite(y)
                    ymin = min(ymin, y)
                    ymax = max(ymax, y)
                end
            end
        end
    end
    if isfinite(ymin) && isfinite(ymax)
        margin = (ymax - ymin) * 0.05
        margin = margin == 0 ? 1.0 : margin
        backend.ylims!(ax, (ymin - margin, ymax + margin))
    end
end

function _parse_panel_ylabel(ylabels, i::Int, is_dual::Bool)
    if ylabels === nothing || i > length(ylabels) || ylabels[i] === nothing
        return ("", "")
    end
    yl = ylabels[i]
    if isa(yl, Tuple) && length(yl) == 2
        return (something(yl[1], ""), something(yl[2], ""))
    end
    return (String(yl), "")
end

"""
Check if a channel spec is a dual-axis tuple: (left_channels, right_channels)
"""
_is_dual_axis(ch_spec) = isa(ch_spec, Tuple) && length(ch_spec) == 2

"""
Parse ylims for a panel. Returns (left_ylims, right_ylims).
- nothing → (nothing, nothing)
- (lo, hi)::Tuple{Number,Number} → ((lo,hi), nothing)  — single axis
- (left, right)::Tuple where either is nothing or a tuple of numbers → dual axis ylims
"""
function _parse_panel_ylims(yl, is_dual::Bool)
    yl === nothing && return (nothing, nothing)
    if !is_dual
        # For single-axis panels, yl should be a simple (lo, hi) or nothing
        # If someone passes a dual-style ylims to a non-dual panel, use the first element
        if isa(yl, Tuple) && length(yl) == 2 && !all(x -> x isa Number, yl)
            return (yl[1], nothing)
        end
        return (yl, nothing)
    end
    # Dual axis
    if isa(yl, Tuple) && length(yl) == 2
        if all(x -> x isa Number, yl)
            # (lo, hi) — treat as left-axis only
            return (yl, nothing)
        else
            return (yl[1], yl[2])
        end
    end
    return (yl, nothing)
end

"""
Plot channels on an axis (left or right), returns the plotted colors for legend building.
"""
function _plot_on_axis!(backend, ax, channels::Vector{Channel}, colors, offset::Int=0; datetimes_cache=nothing)
    entries = []
    for (j, ch) in enumerate(channels)
        color = colors[offset + j]
        dts = datetimes_cache !== nothing ? datetimes_cache[j] : _channel_datetimes(ch)
        p = backend.lines!(ax, dts, ch.values;
            label = ch.name,
            color = color,
        )
        push!(entries, (p, ch.name))
    end
    return entries
end

function _padded_ylims(ymin, ymax)
    (!isfinite(ymin) || !isfinite(ymax)) && return nothing
    if ymin == ymax
        ymin == 0.0 && return (-1.0, 1.0)
        margin = abs(ymin) * 0.05
        return (ymin - margin, ymax + margin)
    end
    margin = (ymax - ymin) * 0.05
    return (ymin - margin, ymax + margin)
end

function _compute_ylims_from_channels(channels::Vector{Channel}, xlims)
    ymin, ymax = Inf, -Inf
    if xlims !== nothing
        xl_lo = Dates.datetime2unix(xlims[1]) * 1000
        xl_hi = Dates.datetime2unix(xlims[2]) * 1000
        for ch in channels
            @inbounds for i in eachindex(ch.values)
                y = ch.values[i]
                isfinite(y) || continue
                t = ch.time[i]
                (xl_lo <= t <= xl_hi) || continue
                ymin = min(ymin, y)
                ymax = max(ymax, y)
            end
        end
    else
        for ch in channels
            @inbounds for y in ch.values
                isfinite(y) || continue
                ymin = min(ymin, y)
                ymax = max(ymax, y)
            end
        end
    end
    return _padded_ylims(ymin, ymax)
end

function _apply_ylims!(backend, ax, yl, channels::Vector{Channel}, xlims)
    if yl !== nothing
        backend.ylims!(ax, yl)
    else
        computed = _compute_ylims_from_channels(channels, xlims)
        computed !== nothing && backend.ylims!(ax, computed)
    end
end

function _plot_channels(channels::Vector{Channel};
        title = "Overview",
        savepath = nothing,
        stacked = false,
        interactive::Bool=false,
        xlims = nothing,
        ylims = nothing,
        smoothing = nothing,
    )
    channels = _maybe_smooth(channels, smoothing)
    colors = _pick_colors(length(channels))
    backend = interactive ? GLMakie : CairoMakie
    backend.activate!()

    if stacked
        fig = backend.Figure(size=PAPER_STACKED_SIZE(length(channels)))
        for (i, ch) in enumerate(channels)
            ax = backend.Axis(fig[i,1];
                ylabel = ch.name,
                xlabel = i == length(channels) ? "Time (UTC)" : "",
                title  = i == 1 ? title : "",
            )
            backend.lines!(ax, _channel_datetimes(ch), ch.values; color=colors[mod1(i, length(colors))])
            xlims !== nothing && backend.xlims!(ax, xlims)
            yl = if ylims !== nothing
                isa(ylims, AbstractVector) ? ylims[i] : ylims
                else
                    nothing
                end
                _apply_ylims!(backend, ax, yl, [ch], xlims)
        end
    else
        fig = backend.Figure(size=PAPER_UNSTACKED_SIZE)
        ax = backend.Axis(fig[1,1]; title, xlabel="Time (UTC)")
        for (i, ch) in enumerate(channels)
            backend.lines!(ax, _channel_datetimes(ch), ch.values;
                label = ch.name,
                color = colors[i],
            )
        end
        backend.axislegend(ax, position=:rt)
        xlims !== nothing && backend.xlims!(ax, xlims)
            # Replace: ylims !== nothing && backend.ylims!(ax, ylims)
        _apply_ylims!(backend, ax, ylims, channels, xlims)
    end

    savepath !== nothing && backend.save(savepath, fig, px_per_unit=PLOT_PX_PER_UNIT)
    return _present(fig; interactive=interactive)
end


function _smooth_channel(ch::Channel, window::Period)
    n = length(ch.time)
    smoothed = fill(NaN, n)
    half_w = Dates.value(Millisecond(window)) / 2.0

    # Get valid indices sorted by time
    valid = [i for i in 1:n if !isnan(ch.time[i]) && isfinite(ch.values[i])]
    sort!(valid, by=i -> ch.time[i])

    nv = length(valid)
    nv == 0 && return Channel(ch.name, ch.time, smoothed)

    # Also need output for indices with valid time but NaN values
    all_valid_time = [i for i in 1:n if !isnan(ch.time[i])]
    sort!(all_valid_time, by=i -> ch.time[i])

    # Build running sum over the sorted valid (finite-value) indices
    # For each output point, find the window using two pointers into `valid`
    lo = 1
    hi = 0
    running_sum = 0.0
    running_count = 0

    vi = 1  # pointer into valid array for lo
    vj = 0  # pointer into valid array for hi

    for k in eachindex(all_valid_time)
        i = all_valid_time[k]
        t = ch.time[i]
        t_lo = t - half_w
        t_hi = t + half_w

        # Advance hi
        while vj < nv && ch.time[valid[vj + 1]] <= t_hi
            vj += 1
            running_sum += ch.values[valid[vj]]
            running_count += 1
        end
        # Advance lo
        while vi <= vj && ch.time[valid[vi]] < t_lo
            running_sum -= ch.values[valid[vi]]
            running_count -= 1
            vi += 1
        end

        smoothed[i] = running_count > 0 ? running_sum / running_count : NaN
    end
    return Channel(ch.name, ch.time, smoothed)
end

_maybe_smooth(ch::Channel, ::Nothing) = ch
_maybe_smooth(ch::Channel, window::Period) = _smooth_channel(ch, window)
_maybe_smooth(channels::Vector{Channel}, window) = [_maybe_smooth(ch, window) for ch in channels]

function plot_channel(ch::Channel;
        ylabel = ch.name,
        title  = ch.name,
        savepath = nothing,
        interactive::Bool=false,
        xlims = nothing,
        ylims = nothing,
        smoothing = nothing,
    )
    ch = _maybe_smooth(ch, smoothing)
    backend = interactive ? GLMakie : CairoMakie
    backend.activate!()
    fig = backend.Figure()
    ax = backend.Axis(fig[1,1]; title, xlabel="Time (UTC)", ylabel)
    backend.lines!(ax, _channel_datetimes(ch), ch.values)
    xlims !== nothing && backend.xlims!(ax, xlims)
    _apply_ylims!(backend, ax, ylims, [ch], xlims)
    savepath !== nothing && backend.save(savepath, fig, px_per_unit=PLOT_PX_PER_UNIT)
    return _present(fig; interactive=interactive)
end

function plot_data(data_or_path; channels=nothing, stacked=false, savepath=nothing, interactive::Bool=false, xlims=nothing, ylims=nothing,
    ylabels=nothing, smoothing = nothing)
    if isa(data_or_path, AbstractVector)
        return plot_datasets(data_or_path; channels=channels, savepath=savepath, interactive=interactive, xlims=xlims, ylims=ylims, ylabels=ylabels, smoothing=smoothing)
    end
    
    data = isa(data_or_path, String) ? load_data(data_or_path) : data_or_path
    selected_channels = _resolve_channels(data, channels)
    title = isa(data_or_path, String) ? basename(data_or_path) : "Data"
    return _plot_channels(selected_channels; title=title, stacked=stacked, savepath=savepath, interactive=interactive, xlims=xlims, ylims=ylims, smoothing=smoothing)
end

function plot_channels(channels::Vector{Channel};
        title = "Overview",
        savepath = nothing,
        stacked = false,
        interactive::Bool=false,
        xlims = nothing,
        ylims = nothing,
    )
    return _plot_channels(channels; title=title, savepath=savepath, stacked=stacked, interactive=interactive, xlims=xlims, ylims=ylims)
end

plot_all(filepath::String; stacked=false, savepath=nothing, interactive::Bool=false, xlims=nothing, ylims=nothing) =
    plot_data(filepath; stacked=stacked, savepath=savepath, interactive=interactive, xlims=xlims, ylims=ylims)

function plot_datasets(datasets::Vector;
        channels=nothing,
        savepath=nothing,
        interactive::Bool=false,
        xlims=nothing,
        ylims=nothing,
        ylabels=nothing,
        smoothing=nothing,
    )
    resolved_datasets = [isa(d, String) ? load_data(d) : d for d in datasets]
    n_datasets = length(resolved_datasets)
    
    channel_specs = if isnothing(channels)
        [nothing for _ in 1:n_datasets]
    elseif !isnothing(channels) && isa(channels[1], AbstractVector) || _is_dual_axis(channels[1])
        channels
    else
        [channels for _ in 1:n_datasets]
    end
    
    backend = interactive ? GLMakie : CairoMakie
    backend.activate!()
    fig_height = PAPER_STACKED_PANEL_HEIGHT * n_datasets
    fig = backend.Figure(size=(PAPER_PLOT_WIDTH, fig_height))
    
    left_axes = []
    right_axes = []
    panel_left_chs = Vector{Vector{Channel}}(undef, n_datasets)
    panel_right_chs = Vector{Vector{Channel}}(undef, n_datasets)
    
    for (i, (data, ch_spec)) in enumerate(zip(resolved_datasets, channel_specs))
        # Parse ylabel for this panel
        yl_label = if ylabels !== nothing && i <= length(ylabels)
            isa(ylabels[i], Tuple) ? ylabels[i][1] : ylabels[i]
        else
            ""
        end
        
        ax = backend.Axis(fig[i, 1];
            xlabel = i == n_datasets ? "Time (UTC)" : "",
            ylabel = yl_label !== nothing ? yl_label : "",
        )
        push!(left_axes, ax)
        
        if _is_dual_axis(ch_spec)
            left_chs = _maybe_smooth(_resolve_channels(data, ch_spec[1]), smoothing)
            right_chs = _maybe_smooth(_resolve_channels(data, ch_spec[2]), smoothing)
            panel_left_chs[i] = left_chs
            panel_right_chs[i] = right_chs
            
            yr_label = if ylabels !== nothing && i <= length(ylabels) && isa(ylabels[i], Tuple)
                ylabels[i][2]
            else
                ""
            end
            
            ax_right = backend.Axis(fig[i, 1];
                ylabel = yr_label !== nothing ? yr_label : "",
                yaxisposition = :right,
                xticklabelsvisible = false,
                xticksvisible = false,
                xlabelvisible = false,
            )
            backend.hidexdecorations!(ax_right)
            backend.linkxaxes!(ax, ax_right)
            push!(right_axes, ax_right)
            
            total = length(left_chs) + length(right_chs)
            colors = _pick_colors(total)
            
            left_entries = _plot_on_axis!(backend, ax, left_chs, colors, 0)
            right_entries = _plot_on_axis!(backend, ax_right, right_chs, colors, length(left_chs))
            
            if !isempty(left_entries)
                backend.Legend(fig[i, 1],
                    [e[1] for e in left_entries],
                    [e[2] for e in left_entries],
                    tellwidth=false, tellheight=false,
                    halign=:left, valign=:top,
                    margin=(10, 10, 10, 10),
                )
            end
            if !isempty(right_entries)
                backend.Legend(fig[i, 1],
                    [e[1] for e in right_entries],
                    [e[2] for e in right_entries],
                    tellwidth=false, tellheight=false,
                    halign=:right, valign=:top,
                    margin=(10, 10, 10, 10),
                )
            end
        else
            push!(right_axes, nothing)
            
            selected_channels = _maybe_smooth(_resolve_channels(data, ch_spec), smoothing)
            panel_left_chs[i] = selected_channels
            panel_right_chs[i] = Channel[]
            
            colors = _pick_colors(length(selected_channels))
            _plot_on_axis!(backend, ax, selected_channels, colors, 0)
            backend.axislegend(ax, position=:rt)
        end
    end
    
    # Link x-axes across all left panels
    if n_datasets > 1
        for i in 2:n_datasets
            backend.linkxaxes!(left_axes[1], left_axes[i])
        end
    end
    # Hide x decorations on all but last panel
    for i in 1:(n_datasets - 1)
        backend.hidexdecorations!(left_axes[i]; label=true, ticklabels=true, ticks=false, grid=false)
    end
    
    # Apply xlims
    if xlims !== nothing
        for ax in left_axes
            backend.xlims!(ax, xlims)
        end
        for ax in right_axes
            ax !== nothing && backend.xlims!(ax, xlims)
        end
    end

    # Apply ylims
    ylims_vec = if ylims === nothing
        [nothing for _ in 1:n_datasets]
    elseif isa(ylims, AbstractVector)
        ylims
    else
        [ylims for _ in 1:n_datasets]
    end
    
    for (i, ax_left) in enumerate(left_axes)
        ax_right = right_axes[i]
        is_dual = ax_right !== nothing
        left_yl, right_yl = _parse_panel_ylims(ylims_vec[i], is_dual)
        
        _apply_ylims!(backend, ax_left, left_yl, panel_left_chs[i], xlims)
        if ax_right !== nothing
            _apply_ylims!(backend, ax_right, right_yl, panel_right_chs[i], xlims)
        end
    end

    savepath !== nothing && backend.save(savepath, fig, px_per_unit=PLOT_PX_PER_UNIT)
    return _present(fig; interactive=interactive)
end