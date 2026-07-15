using CairoMakie

const PAPER_PLOT_WIDTH = 780
const PAPER_STACKED_PANEL_HEIGHT = 270
const PAPER_UNSTACKED_SIZE = (PAPER_PLOT_WIDTH, 400)
const PAPER_STACKED_SIZE(n_channels::Integer) = (PAPER_PLOT_WIDTH, PAPER_STACKED_PANEL_HEIGHT * n_channels)
const PLOT_PX_PER_UNIT = 6 # pixels per unit for saving figures
const PAPER_LINE_COLORS = [
    "#332288",
    "#117733",
    "#44AA99",
    "#88CCEE",
    "#DDCC77",
    "#CC6677",
    "#AA4499",
    "#882255",
]

ANALYSIS_THEME = Theme(
    fontsize = 8,
    linewidth = 1,
    font = "Arial",
    palette = (color = PAPER_LINE_COLORS,),
    Axis = (
        xlabelsize = 8,
        ylabelsize = 8,
        xticklabelsize = 7,
        yticklabelsize = 7,
        titlesize = 9,
        xlabelpadding = 2,
        ylabelpadding = 2,
        xgridvisible = true,
        ygridvisible = true,
        xticksmirrored = false,
        yticksmirrored = false,
        spinewidth = 0.75,
        xtickwidth = 0.75,
        ytickwidth = 0.75,
        xticksize = 3,
        yticksize = 3,
        topspinevisible = false,
        rightspinevisible = false,
    ),
    Legend = (
        framevisible = false,
        labelsize = 7,
        patchsize = (10, 5),
        rowgap = 2,
    ),
    Colorbar = (
        labelsize = 8,
        ticklabelsize = 7,
        width = 8,
        spinewidth = 0.75,
    ),
    figure_padding = 5,
    size = PAPER_UNSTACKED_SIZE,
)

set_theme!(ANALYSIS_THEME)