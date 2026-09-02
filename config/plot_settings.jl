using CairoMakie

const PAPER_PLOT_WIDTH = 780
const PAPER_STACKED_PANEL_HEIGHT = 200
const PAPER_UNSTACKED_SIZE = (PAPER_PLOT_WIDTH, 400)
const PAPER_STACKED_SIZE(n_channels::Integer) = (PAPER_PLOT_WIDTH, PAPER_STACKED_PANEL_HEIGHT * n_channels)
const PLOT_PX_PER_UNIT = 6 # pixels per unit for saving figures
PAPER_LINE_COLORS = [
"#0072B2",  # blue
"#D55E00",  # vermillion
"#009E73",  # green
"#E69F00",  # orange
"#56B4E9",  # sky blue
"#CC79A7",  # pink
"#F0E442",  # yellow
"#000000",  # black
]

# Stage line and label settings
const STAGE_SETTINGS = (
line_color  = (:gray, 0.6),
line_width  = 1,
line_style  = :dash,
font_size   = 10,
font_color  = (:gray40, 0.9),
text_offset = 0.003,
max_length  = 50,
)

ANALYSIS_THEME = Theme(
    fontsize = 16,
    linewidth = 1,
    font = "Arial",
    palette = (color = PAPER_LINE_COLORS,),
    Axis = (
        xlabelsize = 14,
        ylabelsize = 14,
        xticklabelsize = 12,
        yticklabelsize = 12,
        titlesize = 16,
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
        framevisible = true,
        labelsize = 9,
        patchsize = (10, 5),
        rowgap = 2,
    ),
    Colorbar = (
        labelsize = 14,
        ticklabelsize = 12,
        width = 8,
        spinewidth = 0.75,
    ),
    figure_padding = 5,
    size = PAPER_UNSTACKED_SIZE,
)

set_theme!(ANALYSIS_THEME)