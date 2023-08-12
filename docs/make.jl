using EarthData
using Documenter

DocMeta.setdocmeta!(EarthData, :DocTestSetup, :(using EarthData); recursive=true)

makedocs(;
    modules=[EarthData],
    authors="Maarten Pronk <git@evetion.nl> and contributors",
    repo="https://github.com/evetion/EarthData.jl/blob/{commit}{path}#{line}",
    sitename="EarthData.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://evetion.github.io/EarthData.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/evetion/EarthData.jl",
    devbranch="main",
)
