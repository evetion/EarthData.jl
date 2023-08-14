# Generate at least some rudimentary types from JSON Schema
# julia --project gen/codegen.jl

using JSON3
using Downloads: download
using JuliaFormatter: format
const version = "v1.6.4"  # make sure this aligns with EarthData itself

mapping = Dict(
    "string" => "String",
    "number" => "Float64",
    "integer" => "Int64",
    "boolean" => "Bool",
    "array" => "Vector",
    "object" => "Dict",
    "null" => "Nothing",
)

struct_mapping = Dict{String,String}()

function maketitle(x)
    replace(x, " " => "_", "-" => "_")
end

"""Adapted from `copy` in JSON3, but with String keys instead of Symbols."""
function todict(obj::JSON3.Object)
    dict = Dict{String,Any}()
    for (k, v) in obj
        dict[String(k)] = todict(v)
    end
    return dict
end

function todict(obj::Dict{Symbol,Any})
    dict = Dict{String,Any}()
    for (k, v) in obj
        dict[String(k)] = v
    end
    return dict
end

function todict(obj::JSON3.Array{JSON3.Object})
    return map(todict, obj)
end

function todict(obj)
    return obj
end

"""
    deref!(obj::Dict)

Dereference all \$ref keys recursively in a JSON Schema.
"""
function deref!(obj::Dict)
    refs = get(obj, "definitions", Dict())
    deref!(refs, refs)
    deref!(obj, refs)
end

function deref!(obj::Dict, refs)
    for (k, v) in obj
        k == "definitions" && continue
        if isa(v, Dict)
            deref!(v, refs)
        elseif isa(v, Vector)
            foreach(x -> deref!(x, refs), v)
        end
    end
    if haskey(obj, "\$ref")
        k = last(split(obj["\$ref"], "/"))
        for (nk, nv) in refs[k]
            obj[nk] = nv
        end
        obj["typename"] = k
        delete!(obj, "\$ref")
    end
end

deref!(obj, x) = nothing

"""
Derive Julia type from JSON Schema
"""
function parse_type(d::Dict, required = false)::Tuple{String,Vector{String}}
    t = get(d, "type", nothing)
    if isnothing(t)
        if haskey(d, "anyOf")
            TT = map(x -> parse_type(x, true)[1], d["anyOf"])
            T = join(TT, ",")
            if required
                return "Union{$T}", TT
            else
                return "Union{Nothing, $T}", TT
            end
        elseif haskey(d, "\$ref")
            @warn "Still a \$ref in $(keys(d))!"
            T = last(split(d["\$ref"], "/"))
            T = struct_mapping[T]
            return required ? (T, [T]) : ("Union{Nothing, $T}", [T])
        else
            @warn "Unknown type for $(keys(d))"
            return "Any"
        end
    else
        if haskey(d, "typename") && t == "object"
            T = get(d, "typename", "Any")
            TT = [T]
        else
            T = get(mapping, t, "Any")
        end
        if T == "Vector"
            T, TT = parse_type(d["items"], true)
            T = "Vector{$T}"
        else
            TT = [T]
        end
        return required ? (T, TT) : ("Union{Nothing, $T}", TT)
    end
end

"""
Print JSON object into a Julia Struct
"""
function parse_object(io, d::Dict)
    println(io, "abstract type AbstractJSON end\n")
    d["type"] == "object" || return
    structs = Dict()
    for (k, v) in get(d, "definitions", Dict())
        parse_definition(structs, v, k)
    end
    nio = IOBuffer()
    fieldtypes = Set{String}()
    structs[maketitle(d["title"])] = (nio, fieldtypes)
    haskey(d, "description") && println(nio, "\"$(d["description"])\"")
    println(nio, "struct $(maketitle(d["title"])) <: AbstractJSON")
    struct_mapping[d["title"]] = d["title"]
    for (k, v) in d["properties"]
        vk = occursin("-", k) ? "var\"$k\"" : k
        haskey(v, "description") && println(nio, "\t\"$(v["description"])\"")
        T, TT = parse_type(v, k in get(d, "required", String[]))
        push!(fieldtypes, TT...)
        println(nio, "\t$(vk)::$T")
    end
    println(nio, "end")
    println(
        nio,
        "StructTypes.StructType(::Type{$(maketitle(d["title"]))}) = StructTypes.Struct()\n\n",
    )
    _write(io, structs)
end

function _write(io, structs)

    # Reorder structs so that dependencies are satisfied
    kk = collect(keys(structs))
    nio = IOBuffer()
    i = 0
    while !isempty(kk)
        k = popfirst!(kk)
        deps = structs[k][2]
        if any(in(kk), deps)
            push!(kk, k)
        else
            write(nio, take!(structs[k][1]))
        end
        i += 1
        i > 1000 && error("Infinite loop!")
    end
    write(io, take!(nio))
end

"""
Print JSON definition into a Julia Struct
"""
function parse_definition(structs, d::Dict, title)
    T = get(d, "type", nothing)
    if T == "object"
        nio = IOBuffer()
        fieldtypes = Set{String}()
        structs[maketitle(title)] = (nio, fieldtypes)
        haskey(d, "description") && println(nio, "\"$(d["description"])\"")
        println(nio, "struct $(maketitle(title)) <: AbstractJSON")
        struct_mapping[title] = title

        if haskey(d, "oneOf") && !haskey(d, "properties")
            properties = reduce(merge, [get(x, "properties", Dict()) for x in d["oneOf"]])
        else
            properties = get(d, "properties", Dict())
        end

        for (k, v) in properties
            vk = occursin("-", k) ? "var\"$k\"" : k
            haskey(v, "description") && println(nio, "\t\"$(v["description"])\"")
            T, TT = parse_type(v, k in get(d, "required", String[]))
            push!(fieldtypes, TT...)
            println(nio, "\t$(vk)::$T")
        end

        println(nio, "end")
        println(
            nio,
            "StructTypes.StructType(::Type{$(maketitle(title))}) = StructTypes.Struct()\n\n",
        )
    elseif isnothing(T) && haskey(d, "anyOf")
        struct_mapping[title] = "Union{$(join(map(x -> parse_type(x, true)[1], d["anyOf"]), ","))}"
    elseif !isnothing(T)
        struct_mapping[title] = parse_type(d, true)[1]
    else
        @warn "Unknown type $T for $title"
    end
end


fn =
    download("https://cdn.earthdata.nasa.gov/umm/granule/$(version)/umm-g-json-schema.json")
schema = JSON3.read(fn)

# Replace all Symbols with Strings
sch = todict(schema)
# Replace all references with their definitions
deref!(sch)
# Write definitions to file
open("src/granuletypes.jl", "w") do io
    parse_object(io, sch)
end

# run JuliaFormatter on the whole package
format(joinpath(@__DIR__, ".."))
