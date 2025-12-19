using Documenter

push!(LOAD_PATH, joinpath(@__DIR__, ".."))
using DD

DocMeta.setdocmeta!(DD, :DocTestSetup, :(using DD); recursive = true)

makedocs(
    sitename = "DD.jl",
    modules = [DD],
    authors = "Hiroyuki Okamura",
    format = Documenter.HTML(),
    pages = [
        "Home" => "index.md",
    ],
    checkdocs = :none,
)

deploydocs(
    repo = "github.com/JuliaReliab/DD.jl.git",
    push_preview = false,
)
