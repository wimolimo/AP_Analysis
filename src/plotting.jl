using CLOUD18_AP_Analysis
using Statistics: quantile

const _STAGES_DATA = Ref{Vector{Any}}(Any[])

_normalize_channel_key(channel::Channel) = channel.name
_normalize_channel_key(channel::AbstractString) = String(channel)
_normalize_channel_key(channel::Symbol) = String(channel)

function _channel_datetimes(ch::Channel)
    epoch = DateTime(1970, 1, 1)
    return [isnan(t) ? DateTime(0) : epoch + Millisecond(round(Int, t)) for t in ch.time]
end

function _present(fig; interactive::Bool=false, savepath::Union{Nothing,String}=nothing)
    if interactive
        GLMakie.closeall()
        screen = display(GLMakie.Screen(), fig)
        wait(screen)
    else
        # Non-interactive: save to file. Prefer provided savepath, otherwise use display.png
        filepath = savepath !== nothing ? savepath : "display.png"
        try
            save(filepath, fig, px_per_unit=PLOT_PX_PER_UNIT)
            @info "Figure saved to $filepath"
        catch err
            @warn "Failed to save figure to $filepath: $err"
        end
        # Try to open the saved file with the OS default image viewer
        try
            if Sys.iswindows()
                run(`cmd /C start "" "$(filepath)"`)
            elseif Sys.isapple()
                run(`open "$(filepath)"`)
            else
                run(`xdg-open "$(filepath)"`)
            end
        catch err
            @warn "Failed to open $filepath with default viewer: $err"
        end
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

_is_dual_axis(ch_spec) = isa(ch_spec, Tuple) && length(ch_spec) == 2

# Track which backend we've activated to avoid redundant activate! calls
const _ACTIVE_BACKEND = Ref{Symbol}(:cairo)

"""
set_plot_backend!(b)
Set the active plotting backend for subsequent plotting calls. `b` may be
:cairo or :gl. This avoids repeated backend activation when plotting many
figures in a script.
"""
function set_plot_backend!(b::Symbol)
    if b == :gl || b == :glmakie || b == :GLMakie
        GLMakie.activate!()
        _ACTIVE_BACKEND[] = :gl
    elseif b == :cairo || b == :CairoMakie
        CairoMakie.activate!()
        _ACTIVE_BACKEND[] = :cairo
    else
        throw(ArgumentError("Unknown backend: $b (use :gl or :cairo)"))
    end
    try
        set_theme!(ANALYSIS_THEME)
    catch
    end
    return nothing
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

function _plot_on_axis!(ax, channels::Vector{Channel}, colors, offset::Int=0; datetimes_cache=nothing)
    entries = []
    for (j, ch) in enumerate(channels)
        color = colors[offset + j]
        dts = datetimes_cache !== nothing ? datetimes_cache[j] : _channel_datetimes(ch)
        p = lines!(ax, dts, ch.values;
            label = ch.name,
            color = color,
        )
        push!(entries, (p, ch.name))
    end
    return entries
end

"""
Parse ylims for a panel. Returns `(left_ylims, right_ylims)`.
- `nothing` → `(nothing, nothing)`
- `(lo, hi)::Tuple{Number,Number}` → `( (lo,hi), nothing )` for single-axis
- For dual-axis, accept `(left, right)` where either may be `nothing` or a `(lo,hi)` tuple.
"""
function _parse_panel_ylims(yl, is_dual::Bool)
    yl === nothing && return (nothing, nothing)
    if !is_dual
        if isa(yl, Tuple) && length(yl) == 2 && !all(x -> x isa Number, yl)
            return (yl[1], nothing)
        end
        return (yl, nothing)
    end
    if isa(yl, Tuple) && length(yl) == 2
        if all(x -> x isa Number, yl)
            return (yl, nothing)
        else
            return (yl[1], yl[2])
        end
    end
    return (yl, nothing)
end

function _append_to_filename(path::String, tag::String)
    isempty(tag) && return path
    dir = dirname(path)
    base, ext = splitext(basename(path))
    return joinpath(dir, "$(base)_$(tag)$(ext)")
end

function _smoothing_label(window::Period)
    ms = Dates.value(Millisecond(window))
    if ms >= 3600000 && ms % 3600000 == 0
        return "avg$(ms ÷ 3600000)h"
    elseif ms >= 60000 && ms % 60000 == 0
        return "avg$(ms ÷ 60000)min"
    elseif ms >= 1000 && ms % 1000 == 0
        return "avg$(ms ÷ 1000)s"
    else
        return "avg$(ms)ms"
    end
end
_smoothing_label(::Nothing) = ""

"""
Get the label string for a stage.
"""
function _get_stage_label(stage::Dict, label_key)
    if label_key === nothing || label_key == "stage"
        return stage["stage"]
    elseif label_key == "type"
        return "$(stage["stage"]): $(stage["type"])"
    elseif label_key == "onlytype"
        return "$(stage["type"])"
    elseif label_key == "description"
        desc = stage["description"]
        return isempty(desc) ? stage["stage"] : "$(stage["stage"]): $desc"
    elseif label_key == "comments"
        c = stage["comments"]
        return isempty(c) ? stage["stage"] : "$(stage["stage"]): $c"
    elseif label_key == "details"
        d = join(stage["details"], "\n")
        return isempty(d) ? stage["stage"] : "$(stage["stage"]): $d"
    elseif label_key == "full"
        parts = filter(!isempty, [stage["stage"], stage["type"], stage["description"]])
        return join(parts, " - ")
    else
        return stage["stage"]
    end
end

function _truncate(s::String, maxlen::Int=40)
    length(s) <= maxlen && return s
    return s[1:maxlen] * "…"
end

function load_stages!(filepath::String)
    _STAGES_DATA[] = parse_cloud_log(filepath)
    println("Loaded $(length(_STAGES_DATA[])) stages")
end

function _unpack_stages(stages)
    stages === nothing && return (nothing, nothing)
    isempty(_STAGES_DATA[]) && (@warn("No stages loaded. Call load_stages!(filepath) first."); return (nothing, nothing))
    if stages === true
        return (_STAGES_DATA[], nothing)
    else
        return (_STAGES_DATA[], stages)
    end
end

"""
Draw stage vertical lines and labels on a single axis.
"""
function _draw_stages!(ax, stages; xlims=nothing)
    stages_data, label_key = _unpack_stages(stages)
    stages_data === nothing && return

    s = STAGE_SETTINGS
    yl = ax.finallimits[].origin[2], ax.finallimits[].origin[2] + ax.finallimits[].widths[2]
    dt_offset = if xlims !== nothing
        Millisecond(round(Int, Dates.value(Millisecond(xlims[2] - xlims[1])) * s.text_offset))
    else
        Millisecond(60000)
    end

    for stage in stages_data
        t = stage["time"]
        t === nothing && continue
        if xlims !== nothing
            (t < xlims[1] || t > xlims[2]) && continue
        end

        label = _truncate(_get_stage_label(stage, label_key), s.max_length)

        lines!(ax, [t, t], [yl[1], yl[2]];
            color=s.line_color, linewidth=s.line_width, linestyle=s.line_style)

        text!(ax, t + dt_offset, yl[1] + 0.02 * (yl[2] - yl[1]);
            text=label,
            rotation=π / 2,
            fontsize=s.font_size,
            color=s.font_color,
            align=(:left, :top),
        )
    end
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

function _apply_ylims!(ax, yl, channels::Vector{Channel}, xlims)
    if yl !== nothing
        ylims!(ax, yl)
    else
        computed = _compute_ylims_from_channels(channels, xlims)
        computed !== nothing && ylims!(ax, computed)
    end
end

function _smooth_channel(ch::Channel, window::Period)
    n = length(ch.time)
    smoothed = fill(NaN, n)
    half_w = Dates.value(Millisecond(window)) / 2.0

    valid = [i for i in 1:n if !isnan(ch.time[i]) && isfinite(ch.values[i])]
    sort!(valid, by=i -> ch.time[i])

    nv = length(valid)
    nv == 0 && return Channel(ch.name, ch.time, smoothed)

    all_valid_time = [i for i in 1:n if !isnan(ch.time[i])]
    sort!(all_valid_time, by=i -> ch.time[i])

    lo = 1
    hi = 0
    running_sum = 0.0
    running_count = 0

    vi = 1
    vj = 0

    for k in eachindex(all_valid_time)
        i = all_valid_time[k]
        t = ch.time[i]
        t_lo = t - half_w
        t_hi = t + half_w

        while vj < nv && ch.time[valid[vj + 1]] <= t_hi
            vj += 1
            running_sum += ch.values[valid[vj]]
            running_count += 1
        end
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

function _activate_backend!(interactive::Bool; backend_override::Union{Nothing,Symbol}=nothing)
    # Determine desired backend: override if provided, otherwise use interactive flag
    desired = backend_override !== nothing ? backend_override : (interactive ? :gl : :cairo)

    # Only activate if different from currently tracked backend
    if _ACTIVE_BACKEND[] != desired
        try
            if desired == :gl
                GLMakie.activate!()
                _ACTIVE_BACKEND[] = :gl
            else
                CairoMakie.activate!()
                _ACTIVE_BACKEND[] = :cairo
            end
        catch err
            @warn("Failed to activate backend: $err")
        end

        # Reapply the package theme if available so activation doesn't override it.
        try
            set_theme!(ANALYSIS_THEME)
        catch
            # ignore
        end
    end
    return nothing
end

function _plot_channels(channels::Vector{Channel};
        title = "Overview",
        savepath = nothing,
        stacked = false,
        interactive::Bool=false,
        xlims = nothing,
        ylims = nothing,
        smoothing = nothing,
        stages = nothing,
    )
    channels = _maybe_smooth(channels, smoothing)

    stag = _smoothing_label(smoothing)
    if !isempty(stag)
        title = "$title ($stag)"
        savepath = savepath !== nothing ? _append_to_filename(savepath, stag) : nothing
    end

    colors = _pick_colors(length(channels))
    _activate_backend!(interactive)

    if stacked
        fig = Figure(size=PAPER_STACKED_SIZE(length(channels)))
        for (i, ch) in enumerate(channels)
            ax = Axis(fig[i,1];
                ylabel = ch.name,
                xlabel = i == length(channels) ? "Time (UTC)" : "",
                title  = i == 1 ? title : "",
            )
            lines!(ax, _channel_datetimes(ch), ch.values; color=colors[mod1(i, length(colors))])
            xlims !== nothing && Makie.xlims!(ax, xlims)
            yl = if ylims !== nothing
                isa(ylims, AbstractVector) ? ylims[i] : ylims
            else
                nothing
            end
            _apply_ylims!(ax, yl, [ch], xlims)

            stages !== nothing && _draw_stages!(ax, stages; xlims=xlims)
        end
    else
        fig = Figure(size=PAPER_UNSTACKED_SIZE)
        ax = Axis(fig[1,1]; title, xlabel="Time (UTC)")
        for (i, ch) in enumerate(channels)
            lines!(ax, _channel_datetimes(ch), ch.values;
                label = ch.name,
                color = colors[i],
            )
        end
        axislegend(ax, position=:rt)
        xlims !== nothing && Makie.xlims!(ax, xlims)
        _apply_ylims!(ax, ylims, channels, xlims)

        stages !== nothing && _draw_stages!(ax, stages; xlims=xlims)
    end

    savepath !== nothing && save(savepath, fig, px_per_unit=PLOT_PX_PER_UNIT)
    return _present(fig; interactive=interactive, savepath=savepath)
end

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

    stag = _smoothing_label(smoothing)
    if !isempty(stag)
        title = "$title ($stag)"
        savepath = savepath !== nothing ? _append_to_filename(savepath, stag) : nothing
    end

    _activate_backend!(interactive)
    fig = Figure()
    ax = Axis(fig[1,1]; title, xlabel="Time (UTC)", ylabel)
    lines!(ax, _channel_datetimes(ch), ch.values)
    xlims !== nothing && Makie.xlims!(ax, xlims)
    _apply_ylims!(ax, ylims, [ch], xlims)
    savepath !== nothing && save(savepath, fig, px_per_unit=PLOT_PX_PER_UNIT)
    return _present(fig; interactive=interactive, savepath=savepath)
end

"""
Plot data from dataset
"""
function plot_data(data_or_path; channels=nothing, stacked=false, savepath=nothing,
        interactive::Bool=false, xlims=nothing, ylims=nothing,
        ylabels=nothing, smoothing=nothing,
        stages=nothing)
    if isa(data_or_path, AbstractVector)
        return plot_datasets(data_or_path; channels=channels, savepath=savepath,
            interactive=interactive, xlims=xlims, ylims=ylims, ylabels=ylabels,
            smoothing=smoothing, stages=stages)
    end
    
    data = isa(data_or_path, String) ? load_data(data_or_path) : data_or_path
    selected_channels = _resolve_channels(data, channels)
    title = isa(data_or_path, String) ? basename(data_or_path) : "Data"
    return _plot_channels(selected_channels; title=title, stacked=stacked, savepath=savepath,
        interactive=interactive, xlims=xlims, ylims=ylims, smoothing=smoothing,
        stages=stages)
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
        stages=nothing,
    )
    # Load any string paths, but don't force type — keep SMPSData as-is
    resolved_datasets = [isa(d, String) ? load_data(d) : d for d in datasets]
    n_datasets = length(resolved_datasets)
    
    channel_specs = if isnothing(channels)
        [nothing for _ in 1:n_datasets]
    elseif isa(channels, AbstractVector) && (length(channels) == n_datasets) &&
           (isa(channels[1], AbstractVector) || _is_dual_axis(channels[1]))
        channels
    else
        [channels for _ in 1:n_datasets]
    end
    
    _activate_backend!(interactive)
    fig_height = PAPER_STACKED_PANEL_HEIGHT * n_datasets
    fig = Figure(size=(PAPER_PLOT_WIDTH, fig_height))
    left_axes = []
    right_axes = []
    heatmap_handles = []  # track (panel_index, heatmap_object) for colorbars
    panel_left_chs = Vector{Vector{Channel}}(undef, n_datasets)
    panel_right_chs = Vector{Vector{Channel}}(undef, n_datasets)
    has_heatmap = false
    
    for (i, (data, ch_spec)) in enumerate(zip(resolved_datasets, channel_specs))

        # ── HEATMAP panel for SMPSData ──────────────────────────────
        if data isa SMPSData
            has_heatmap = true

            yl_label = if ylabels !== nothing && i <= length(ylabels)
                isa(ylabels[i], Tuple) ? ylabels[i][1] : ylabels[i]
            else
                "Diameter [nm]"
            end

            ax = Axis(fig[i, 1];
                xlabel = i == n_datasets ? "Time (UTC)" : "",
                ylabel = yl_label,
                yscale = log10,
            )
            push!(left_axes, ax)
            push!(right_axes, nothing)
            panel_left_chs[i] = Channel[]
            panel_right_chs[i] = Channel[]

            # Prepare concentration matrix, replacing NaN/non-positive for log scale
            conc = copy(data.dNdlogDp)
            for i in eachindex(conc)
                if isnan(conc[i])
                    continue  # stays NaN → nan_color
                elseif !isfinite(conc[i]) || conc[i] <= 0
                    conc[i] = 1e-30  # tiny positive → below colorrange → lowclip
                end
            end
            
            # Compute a sensible color range from positive values
            pos_vals = filter(x -> isfinite(x) && x > 0, vec(conc))
            crange = if !isempty(pos_vals)
                (max(1.0, quantile(pos_vals, 0.01)), quantile(pos_vals, 0.99))
            else
                (1.0, 1e4)
            end

            # Convert timestamps to the same Float64 Makie uses internally for DateTime
            time_float = Float64.(Dates.value.(data.time))

            hm = heatmap!(ax, time_float, data.diameters, conc;
                colormap = :inferno,
                colorscale = log10,
                colorrange = crange,
                nan_color = :white,
            )

            # Colorbar label from ylabels tuple or default
            cb_label = if ylabels !== nothing && i <= length(ylabels) && isa(ylabels[i], Tuple) && length(ylabels[i]) >= 2
                ylabels[i][2]
            else
                "dN/dlogDp [cm⁻³]"
            end
            Colorbar(fig[i, 2], hm; label = cb_label, width = 15)
            colgap!(fig.layout, 1, -46)  # 5 pixels gap between column 1 and 2

            if i != n_datasets
                hidexdecorations!(ax; label=true, ticklabels=true, ticks=false, grid=false)
            end
            continue
        end

        # ── LINE plot panel for Dataset ─────────────────────────────
        yl_label = if ylabels !== nothing && i <= length(ylabels)
            isa(ylabels[i], Tuple) ? ylabels[i][1] : ylabels[i]
        else
            ""
        end
        
        ax = Axis(fig[i, 1];
            xlabel = i == n_datasets ? "Time (UTC)" : "",
            ylabel = yl_label !== nothing ? yl_label : "",
        )
        push!(left_axes, ax)
        
        if _is_dual_axis(ch_spec)
            left_chs = _maybe_smooth(_resolve_channels(data, ch_spec[1]), smoothing)
            right_chs = _maybe_smooth(_resolve_channels(data, ch_spec[2]), smoothing)
            panel_left_chs[i] = left_chs
            panel_right_chs[i] = right_chs

            if isempty(right_chs)
                push!(right_axes, nothing)
                colors = _pick_colors(length(left_chs))
                _plot_on_axis!(ax, left_chs, colors, 0)
                axislegend(ax, position=:lt)
            else
                yr_label = if ylabels !== nothing && i <= length(ylabels) && isa(ylabels[i], Tuple)
                    ylabels[i][2]
                else
                    ""
                end

                ax_right = Axis(fig[i, 1];
                    ylabel = yr_label !== nothing ? yr_label : "",
                    yaxisposition = :right,
                    xticklabelsvisible = false,
                    xticksvisible = false,
                    xlabelvisible = false,
                )
                hidexdecorations!(ax_right)
                linkxaxes!(ax, ax_right)
                push!(right_axes, ax_right)

                total = length(left_chs) + length(right_chs)
                colors = _pick_colors(total)

                left_entries = _plot_on_axis!(ax, left_chs, colors, 0)
                right_entries = _plot_on_axis!(ax_right, right_chs, colors, length(left_chs))
            
                if !isempty(left_entries)
                    Legend(fig[i, 1],
                        [e[1] for e in left_entries],
                        [e[2] for e in left_entries],
                        tellwidth=false, tellheight=false,
                        halign=:left, valign=:top,
                        margin=(10, 10, 10, 10),
                    )
                end
                if !isempty(right_entries)
                    Legend(fig[i, 1],
                        [e[1] for e in right_entries],
                        [e[2] for e in right_entries],
                        tellwidth=false, tellheight=false,
                        halign=:right, valign=:top,
                        margin=(10, 10, 10, 10),
                    )
                end
            end
        else
            push!(right_axes, nothing)
            
            selected_channels = _maybe_smooth(_resolve_channels(data, ch_spec), smoothing)
            panel_left_chs[i] = selected_channels
            panel_right_chs[i] = Channel[]
            
            colors = _pick_colors(length(selected_channels))
            _plot_on_axis!(ax, selected_channels, colors, 0)
            axislegend(ax, position=:lt)
        end
    end

    stag = _smoothing_label(smoothing)
    if !isempty(stag)
        savepath = savepath !== nothing ? _append_to_filename(savepath, stag) : nothing
        left_axes[1].title[] = stag
    end
    
    if n_datasets > 1
        # Find first non-heatmap axis to use as link reference
        ref_idx = findfirst(i -> !(resolved_datasets[i] isa SMPSData), 1:n_datasets)
        if ref_idx !== nothing
            for i in 1:n_datasets
                i == ref_idx && continue
                resolved_datasets[i] isa SMPSData && continue
                linkxaxes!(left_axes[ref_idx], left_axes[i])
            end
        end
    end

    for i in 1:(n_datasets - 1)
        resolved_datasets[i] isa SMPSData && continue
        hidexdecorations!(left_axes[i]; label=true, ticklabels=true, ticks=false, grid=false)
    end
    
    if xlims !== nothing
        epoch = DateTime(1970, 1, 1)
        for (i, ax) in enumerate(left_axes)
            if resolved_datasets[i] isa SMPSData
                xl_ms = (Float64(Dates.value(xlims[1])), Float64(Dates.value(xlims[2])))
                Makie.xlims!(ax, xl_ms)
            else
                Makie.xlims!(ax, xlims)
            end
        end
        for ax in right_axes
            ax !== nothing && Makie.xlims!(ax, xlims)
        end
    end

    ylims_vec = if ylims === nothing
        [nothing for _ in 1:n_datasets]
    elseif isa(ylims, AbstractVector)
        ylims
    else
        [ylims for _ in 1:n_datasets]
    end
    
    for (i, ax_left) in enumerate(left_axes)
        # Skip ylims for heatmap panels — handled by the heatmap itself
        resolved_datasets[i] isa SMPSData && continue

        ax_right = right_axes[i]
        is_dual = ax_right !== nothing
        left_yl, right_yl = _parse_panel_ylims(ylims_vec[i], is_dual)
        
        _apply_ylims!(ax_left, left_yl, panel_left_chs[i], xlims)
        if ax_right !== nothing
            _apply_ylims!(ax_right, right_yl, panel_right_chs[i], xlims)
        end
    end

    stages_data, stage_label = _unpack_stages(stages)
    if stages_data !== nothing
        for ax in left_axes
            _draw_stages!(ax, stages; xlims=xlims)
        end
    end

    savepath !== nothing && save(savepath, fig, px_per_unit=PLOT_PX_PER_UNIT)
    return _present(fig; interactive=interactive, savepath=savepath)
end