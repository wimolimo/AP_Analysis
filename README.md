# CLOUD18_AP_Analysis

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://Timo.github.io/CLOUD18_AP_Analysis.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://Timo.github.io/CLOUD18_AP_Analysis.jl/dev/)
[![Build Status](https://github.com/Timo/CLOUD18_AP_Analysis.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/Timo/CLOUD18_AP_Analysis.jl/actions/workflows/CI.yml?query=branch%3Amaster)
[![Coverage](https://codecov.io/gh/Timo/CLOUD18_AP_Analysis.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/Timo/CLOUD18_AP_Analysis.jl)


# Plotting Guide

## Overview

The plotting module provides flexible functions for visualizing time-series data from CLOUD18 datasets. You can create single-channel plots, multi-channel overlays, stacked panels, multi-dataset comparisons, and dual y-axis plots.

---

## Quick Start

```julia
using CLOUD18_AP_Analysis

# Load data
data = load_data("path/to/data.hdf5")

# Simplest plot: all channels overlaid
plot_data(data)

# Plot specific channels
plot_data(data, channels=["TE_Calib_1", "TE_Calib_2"])
```

---

## Functions

| Function | Use Case |
|---|---|
| `plot_data` | Main entry point — handles single datasets, multiple datasets, and strings (file paths) |
| `plot_channel` | Plot a single `Channel` object |
| `plot_channels` | Plot a vector of `Channel` objects |
| `plot_all` | Shorthand for plotting all channels from a file path |

---

## Single Dataset

### All channels overlaid on one axis

```julia
plot_data(data)
```

### Selected channels overlaid

```julia
plot_data(data, channels=["TE_Calib_1", "TE_Calib_2", "TE_Calib_3"])
```

### Stacked panels (one channel per panel)

```julia
plot_data(data, channels=["TE_Calib_1", "TE_Calib_2"], stacked=true)
```

### From file path

```julia
plot_data("path/to/data.hdf5", channels=["o3", "o3_psi"])
```

---

## Multiple Datasets

Pass a vector of datasets (or file paths) to create stacked panels, one per dataset.

### Basic multi-dataset plot

```julia
data_temp = load_data("temperature.hdf5")
data_o3   = load_data("ozone.hdf5")
data_OH   = load_data("OH.hdf5")

plot_data([data_temp, data_o3, data_OH])
```

### Selecting channels per dataset

Use a vector of vectors. Each inner vector specifies which channels to show in that panel. Use `[]` to show all channels from that dataset.

```julia
plot_data([data_temp, data_o3, data_OH],
    channels=[
        ["TE_Calib_1", "TE_Calib_2", "TE_Calib_3", "TE_Calib_4"],  # panel 1
        [],                                                          # panel 2: all channels
        ["OH_ppt", "HO2_ppt"],                                      # panel 3
    ],
)
```

---

## Dual Y-Axis (Split Axis)

To plot different channels on left and right y-axes within the same panel, pass a **tuple of two vectors** instead of a plain vector for that panel's channel specification.

### Syntax

```julia
(["left_channel_1", "left_channel_2"], ["right_channel_1", "right_channel_2"])
```

### Example

```julia
plot_data([data_temp, data_o3, data_OH],
    channels=[
        ["TE_Calib_1", "TE_Calib_2", "TE_Calib_3", "TE_Calib_4"],  # single y-axis
        [],                                                          # single y-axis
        (["OH_ppt"], ["HO2_ppt"]),                                   # dual y-axis
    ],
)
```

- First vector in the tuple → **left y-axis**
- Second vector in the tuple → **right y-axis**
- Each side can have any number of channels
- Legends are placed on the corresponding side (left legend for left-axis channels, right legend for right-axis channels)

### More channels per side

```julia
channels=[
    (["OH_ppt", "HO2_ppt"], ["RO2_crosstalk_ppt", "OH_det_lim_ppt"]),
]
```

---

## Setting Axis Limits

### X-Limits (shared across all panels)

Pass a tuple of `DateTime` values:

```julia
using Dates

plot_data(data,
    xlims=(DateTime(2025, 9, 22, 0, 0, 0), DateTime(2025, 9, 22, 12, 0, 0)),
)
```

Or convert from Unix timestamps (in seconds):

```julia
plot_data(data,
    xlims=(Dates.unix2datetime(1758550000 - 3600), Dates.unix2datetime(1759010000 + 3600)),
)
```

### Y-Limits

#### Single dataset

```julia
# Single ylims for the whole plot
plot_data(data, ylims=(-5, 120))
```

#### Multiple datasets — per-panel ylims

Pass a vector with one entry per panel. Use `nothing` for auto-scaling:

```julia
plot_data([data_temp, data_o3, data_OH],
    ylims=[nothing, (-5, 120), nothing],
)
```

#### Dual-axis ylims

For dual-axis panels, pass a tuple of `(left_ylims, right_ylims)`:

```julia
plot_data([data_temp, data_o3, data_OH],
    channels=[
        ["TE_Calib_1", "TE_Calib_2", "TE_Calib_3", "TE_Calib_4"],
        [],
        (["OH_ppt"], ["HO2_ppt"]),
    ],
    ylims=[
        nothing,                        # panel 1: auto
        (-5, 120),                      # panel 2: fixed
        ((-0.5, 2.2), (-0.1, 0.2)),    # panel 3: left=(-0.5,2.2), right=(-0.1,0.2)
    ],
)
```

You can also set only one side:

```julia
ylims=[
    nothing,
    (-5, 120),
    (nothing, (0, 50)),   # left=auto, right=(0,50)
]
```

### Auto Y-Limits with X-Limits

When `xlims` is set and `ylims` is `nothing` for a panel, the y-axis automatically adjusts to fit only the data visible within the x-window (with a 5% margin).

---

## Saving Plots

Pass `savepath` to save to a file. The format is determined by the file extension (`.png`, `.pdf`, `.svg`, etc.):

```julia
plot_data(data, savepath="output/my_plot.png")
plot_data(data, savepath="output/my_plot.pdf")
```

---

## Interactive Mode

Set `interactive=true` to open plots in an interactive GLMakie window (pan, zoom, etc.):

```julia
plot_data(data, interactive=true)
```

By default, plots use CairoMakie (static rendering, suitable for saving).

---

## Full Example

```julia
using CLOUD18_AP_Analysis
using Dates

# Load datasets
data_temp = load_data("temperature.hdf5")
data_o3   = load_data("ozone.hdf5")
data_OH   = load_data("OH.hdf5")

# Multi-dataset plot with dual axis, custom limits, saved to file
plot_data([data_temp, data_o3, data_OH],
    channels=[
        ["TE_Calib_1", "TE_Calib_2", "TE_Calib_3", "TE_Calib_4"],
        [],
        (["OH_ppt"], ["HO2_ppt"]),
    ],
    ylims=[nothing, (-5, 120), ((-0.5, 2.2), (-0.1, 0.2))],
    xlims=(Dates.unix2datetime(1758550000 - 3600), Dates.unix2datetime(1759010000 + 3600)),
    savepath="output/overview.png",
)
```

---

## Summary Table

| Feature | Syntax |
|---|---|
| All channels | `plot_data(data)` |
| Select channels | `channels=["A", "B"]` |
| Stacked panels | `stacked=true` |
| Multiple datasets | `plot_data([data1, data2])` |
| Per-panel channels | `channels=[["A"], [], ["B", "C"]]` |
| Dual y-axis | `channels=[(["A"], ["B"])]` |
| X limits | `xlims=(DateTime(...), DateTime(...))` |
| Y limits per panel | `ylims=[nothing, (lo, hi), nothing]` |
| Dual-axis Y limits | `ylims=[(left_yl, right_yl)]` |
| Auto Y in X window | Set `xlims`, leave `ylims=nothing` |
| Save to file | `savepath="plot.png"` |
| Interactive | `interactive=true` |
```