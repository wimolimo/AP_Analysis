_normalize_channel_key(channel::Channel) = channel.name
_normalize_channel_key(channel::AbstractString) = String(channel)
_normalize_channel_key(channel::Symbol) = String(channel)

function _channel_datetimes(ch::Channel)
    epoch = DateTime(1970, 1, 1)
    return [isnan(t) ? DateTime(0) : epoch + Millisecond(round(Int, t)) for t in ch.time]
end

function _present(fig; interactive::Bool=false)
    if interactive
        GLMakie.activate!()
        display(GLMakie.Screen(), fig)
    else
        CairoMakie.activate!()
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
function _plot_on_axis!(backend, ax, channels::Vector{Channel}, colors, offset::Int=0)
    entries = []
    for (j, ch) in enumerate(channels)
        color = colors[offset + j]
        p = backend.lines!(ax, _channel_datetimes(ch), ch.values;
            label = ch.name,
            color = color,
        )
        push!(entries, (p, ch.name))
    end
    return entries
end

"""
Apply ylims to an axis, with auto-ylims fallback when xlims is set.
"""
function _apply_ylims!(backend, ax, yl, xlims)
    if yl !== nothing
        backend.ylims!(ax, yl)
    elseif xlims !== nothing
        _auto_ylims!(backend, ax, xlims)
    end
end

function _plot_channels(channels::Vector{Channel};
        title = "Overview",
        savepath = nothing,
        stacked = false,
        interactive::Bool=false,
        xlims = nothing,
        ylims = nothing,
    )
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
            if ylims !== nothing
                if isa(ylims, AbstractVector)
                    ylims[i] !== nothing && backend.ylims!(ax, ylims[i])
                else
                    backend.ylims!(ax, ylims)
                end
            end
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
        ylims !== nothing && backend.ylims!(ax, ylims)
    end

    savepath !== nothing && backend.save(savepath, fig, px_per_unit=PLOT_PX_PER_UNIT)
    return _present(fig; interactive=interactive)
end

function plot_channel(ch::Channel;
        ylabel = ch.name,
        title  = ch.name,
        savepath = nothing,
        interactive::Bool=false,
        xlims = nothing,
        ylims = nothing,
    )
    backend = interactive ? GLMakie : CairoMakie
    backend.activate!()
    fig = backend.Figure()
    ax = backend.Axis(fig[1,1]; title, xlabel="Time (UTC)", ylabel)
    backend.lines!(ax, _channel_datetimes(ch), ch.values)
    xlims !== nothing && backend.xlims!(ax, xlims)
    ylims !== nothing && backend.ylims!(ax, ylims)
    savepath !== nothing && backend.save(savepath, fig, px_per_unit=PLOT_PX_PER_UNIT)
    return _present(fig; interactive=interactive)
end

function plot_data(data_or_path; channels=nothing, stacked=false, savepath=nothing, interactive::Bool=false, xlims=nothing, ylims=nothing)
    if isa(data_or_path, AbstractVector)
        return plot_datasets(data_or_path; channels=channels, savepath=savepath, interactive=interactive, xlims=xlims, ylims=ylims)
    end
    
    data = isa(data_or_path, String) ? load_data(data_or_path) : data_or_path
    selected_channels = _resolve_channels(data, channels)
    title = isa(data_or_path, String) ? basename(data_or_path) : "Data"
    return _plot_channels(selected_channels; title=title, stacked=stacked, savepath=savepath, interactive=interactive, xlims=xlims, ylims=ylims)
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
    right_axes = []  # nothing if no right axis for that panel
    
    for i in 1:n_datasets
        ax = backend.Axis(fig[i, 1]; xlabel=i == n_datasets ? "Time (UTC)" : "", ylabel="")
        push!(left_axes, ax)
        
        ch_spec = channel_specs[i]
        if _is_dual_axis(ch_spec)
            ax_right = backend.Axis(fig[i, 1];
                ylabel = "",
                yaxisposition = :right,
                yticklabelcolor = :gray50,
                ylabelcolor = :gray50,
                xticklabelsvisible = false,
                xticksvisible = false,
                xlabelvisible = false,
            )
            # Hide x-axis decorations on right axis entirely
            backend.hidexdecorations!(ax_right)
            # Link x-axes between left and right
            backend.linkxaxes!(ax, ax_right)
            push!(right_axes, ax_right)
        else
            push!(right_axes, nothing)
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
    
    for (i, (data, ch_spec)) in enumerate(zip(resolved_datasets, channel_specs))
        ax_left = left_axes[i]
        ax_right = right_axes[i]
        
        if _is_dual_axis(ch_spec)
            left_chs = _resolve_channels(data, ch_spec[1])
            right_chs = _resolve_channels(data, ch_spec[2])
            total = length(left_chs) + length(right_chs)
            colors = _pick_colors(total)
            
            left_entries = _plot_on_axis!(backend, ax_left, left_chs, colors, 0)
            right_entries = _plot_on_axis!(backend, ax_right, right_chs, colors, length(left_chs))
            
            # Separate legends for each axis
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
            selected_channels = _resolve_channels(data, ch_spec)
            colors = _pick_colors(length(selected_channels))
            _plot_on_axis!(backend, ax_left, selected_channels, colors, 0)
            backend.axislegend(ax_left, position=:rt)
        end
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
        
        _apply_ylims!(backend, ax_left, left_yl, xlims)
        if ax_right !== nothing
            _apply_ylims!(backend, ax_right, right_yl, xlims)
        end
    end

    savepath !== nothing && backend.save(savepath, fig, px_per_unit=PLOT_PX_PER_UNIT)
    return _present(fig; interactive=interactive)
end