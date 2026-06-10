using CLOUD18_AP_Analysis
using Documenter

DocMeta.setdocmeta!(CLOUD18_AP_Analysis, :DocTestSetup, :(using CLOUD18_AP_Analysis); recursive=true)

makedocs(;
    modules=[CLOUD18_AP_Analysis],
    authors="Timo Wittler wittler.timo@uibk.ac.at",
    sitename="CLOUD18_AP_Analysis.jl",
    format=Documenter.HTML(;
        canonical="https://Timo.github.io/CLOUD18_AP_Analysis.jl",
        edit_link="master",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/Timo/CLOUD18_AP_Analysis.jl",
    devbranch="master",
)
