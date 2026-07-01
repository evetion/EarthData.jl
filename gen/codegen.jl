# Generate at least some rudimentary types from JSON Schema
# julia --project gen/codegen.jl

using JSON3
using Downloads: download
using JuliaFormatter: format
# Check https://wiki.earthdata.nasa.gov/spaces/CMR/pages/49448405/UMM+Documents

"""
Describe one UMM schema to fetch and the Julia module to generate from it.

`optional_fields` records known CMR response fields that violate the published
schema but still need to parse.
"""
Base.@kwdef struct SchemaSpec
    family::String
    suffix::String
    version::String
    module_name::String
    output::String
    optional_fields::Set{Tuple{String,String}} = Set{Tuple{String,String}}()
end

const schemas = [
    SchemaSpec(
        family="granule",
        suffix="g",
        version="v1.6.6",
        module_name="Granules",
        output=joinpath("src", "umm", "granules.jl"),
    ),
    SchemaSpec(
        family="collection",
        suffix="c",
        version="v1.17.0",
        module_name="Collections",
        output=joinpath("src", "umm", "collections.jl"),
        # Some CMR collection records contain legacy MetadataDates with a Type
        # but no Date even though the common schema marks Date as required.
        optional_fields=Set([("DateType", "Date")]),
    ),
]

mapping = Dict(
    "string" => "String",
    "number" => "Float64",
    "integer" => "Int64",
    "boolean" => "Bool",
    "array" => "Vector",
    "object" => "Dict",
    "null" => "Nothing",
)

"""Convert schema titles into the simple Julia identifiers used here."""
function maketitle(x)
    replace(x, " " => "_", "-" => "_")
end

"""Normalize JSON3 containers to Julia containers with String keys."""
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
Return external schema files referenced by `\$ref` values.

Internal references such as `#/definitions/Foo` stay in the current schema.
"""
function collect_external_refs(obj)::Set{String}
    refs = Set{String}()
    collect_external_refs!(refs, obj)
    return refs
end

function collect_external_refs!(refs::Set{String}, obj::Dict)
    if haskey(obj, "\$ref")
        ref = obj["\$ref"]
        if ref isa AbstractString
            file = first(split(ref, "#"; limit=2))
            isempty(file) || push!(refs, file)
        end
    end
    foreach(v -> collect_external_refs!(refs, v), values(obj))
    return refs
end

function collect_external_refs!(refs::Set{String}, obj::Vector)
    foreach(v -> collect_external_refs!(refs, v), obj)
    return refs
end

collect_external_refs!(refs::Set{String}, obj) = refs

"""
Return true when a schema node should be emitted as a Julia struct.

Some UMM definitions use `oneOf` with object variants; this generator treats
those variants as one struct with merged fields.
"""
function is_object_schema(d::Dict)
    get(d, "type", nothing) == "object" ||
        (haskey(d, "oneOf") && all(x -> get(x, "type", nothing) == "object", d["oneOf"]))
end

"""Return object properties, merging object-only `oneOf` variants when needed."""
function schema_properties(d::Dict)
    if haskey(d, "oneOf") && !haskey(d, "properties")
        return reduce(merge, [get(x, "properties", Dict()) for x in d["oneOf"]])
    else
        return get(d, "properties", Dict())
    end
end

"""
Return whether `field` should be generated as non-nullable.

This combines the schema's `required` list with per-schema exceptions for
legacy CMR records that omit fields marked as required by the schema.
"""
function is_required_field(
    d::Dict,
    title::AbstractString,
    field::AbstractString,
    spec::SchemaSpec,
)
    field in get(d, "required", String[]) && !((title, field) in spec.optional_fields)
end

"""Return the directory prefix of a schema URL."""
function schema_directory(url::AbstractString)
    replace(url, r"[^/]+$" => "")
end

"""Resolve a schema reference against the current schema URL."""
function schema_ref_url(base_url::AbstractString, ref::AbstractString)
    startswith(ref, "http://") || startswith(ref, "https://") ? ref : base_url * ref
end

"""
Fetch sibling schemas and merge their definitions into `schema`.

After this pass, `deref!` can resolve external and internal references from
one local definitions table.
"""
function merge_external_definitions!(schema::Dict, url::AbstractString)
    base_url = schema_directory(url)
    definitions = get!(schema, "definitions", Dict{String,Any}())
    refs = collect(collect_external_refs(schema))
    seen = Set{String}()

    while !isempty(refs)
        ref = popfirst!(refs)
        ref in seen && continue
        push!(seen, ref)

        # External schemas can themselves reference more sibling schemas.
        external_url = schema_ref_url(base_url, ref)
        external_schema = todict(JSON3.read(read(download(external_url), String)))
        for (k, v) in get(external_schema, "definitions", Dict{String,Any}())
            haskey(definitions, k) || (definitions[k] = v)
        end

        append!(refs, setdiff(collect(collect_external_refs(external_schema)), seen))
    end

    return schema
end

"""
    parse_type(d, struct_mapping, required=false) -> (type, deps)

Translate one JSON Schema node into Julia type source.

The returned dependency list feeds `_write`, which emits generated structs only
after the structs they reference.
"""
function parse_type(
    d::Dict,
    struct_mapping::Dict{String,String},
    required=false,
)::Tuple{String,Vector{String}}
    t = get(d, "type", nothing)
    if isnothing(t)
        if haskey(d, "anyOf")
            TT = map(x -> parse_type(x, struct_mapping, true)[1], d["anyOf"])
            T = join(TT, ",")
            if required
                return "Union{$T}", TT
            else
                return "Union{Nothing, $T}", TT
            end
        elseif haskey(d, "typename")
            T = get(struct_mapping, d["typename"], maketitle(d["typename"]))
            return required ? (T, [T]) : ("Union{Nothing, $T}", [T])
        elseif haskey(d, "oneOf")
            TT = unique(map(x -> parse_type(x, struct_mapping, true)[1], d["oneOf"]))
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
            return "Any", ["Any"]
        end
    else
        if haskey(d, "typename") && t == "object"
            T = get(d, "typename", "Any")
            TT = [T]
        else
            T = get(mapping, t, "Any")
        end
        if T == "Vector"
            T, TT = parse_type(d["items"], struct_mapping, true)
            T = "Vector{$T}"
        else
            TT = [T]
        end
        return required ? (T, TT) : ("Union{Nothing, $T}", TT)
    end
end

"""
    parse_object(io, d, struct_mapping, spec)

Emit the top-level schema object and all nested object definitions.

Definitions are buffered first because schema order does not guarantee Julia
type dependency order.
"""
function parse_object(io, d::Dict, struct_mapping::Dict{String,String}, spec::SchemaSpec)
    d["type"] == "object" || return
    structs = Dict()

    # Build buffers for every named definition before writing anything.
    # `_write` later orders those buffers using the recorded field dependencies.
    for (k, v) in get(d, "definitions", Dict())
        parse_definition(structs, v, k, struct_mapping, spec)
    end

    # Treat the root schema like another definition so it participates in the
    # same dependency ordering as all nested types.
    nio = IOBuffer()
    fieldtypes = Set{String}()
    structs[maketitle(d["title"])] = (nio, fieldtypes)
    haskey(d, "description") && println(nio, "\"$(d["description"])\"")
    println(nio, "struct $(maketitle(d["title"])) <: AbstractJSON")
    struct_mapping[d["title"]] = maketitle(d["title"])
    for (k, v) in d["properties"]
        # JSON field names with hyphens need quoted identifiers in Julia.
        vk = occursin("-", k) ? "var\"$k\"" : k
        haskey(v, "description") && println(nio, "\t\"$(v["description"])\"")
        T, TT = parse_type(v, struct_mapping, is_required_field(d, d["title"], k, spec))
        # Track referenced struct names so `_write` can emit dependencies first.
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

"""Write buffered struct definitions in dependency order."""
function _write(io, structs)

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
    parse_definition(structs, d, title, struct_mapping, spec)

Buffer one schema definition as a generated struct or as a type mapping.
"""
function parse_definition(
    structs,
    d::Dict,
    title,
    struct_mapping::Dict{String,String},
    spec::SchemaSpec,
)
    T = get(d, "type", nothing)
    if is_object_schema(d)
        nio = IOBuffer()
        fieldtypes = Set{String}()
        structs[maketitle(title)] = (nio, fieldtypes)
        haskey(d, "description") && println(nio, "\"$(d["description"])\"")
        println(nio, "struct $(maketitle(title)) <: AbstractJSON")
        struct_mapping[title] = maketitle(title)
        properties = schema_properties(d)

        for (k, v) in properties
            vk = occursin("-", k) ? "var\"$k\"" : k
            haskey(v, "description") && println(nio, "\t\"$(v["description"])\"")
            T, TT = parse_type(v, struct_mapping, is_required_field(d, title, k, spec))
            push!(fieldtypes, TT...)
            println(nio, "\t$(vk)::$T")
        end

        println(nio, "end")
        println(
            nio,
            "StructTypes.StructType(::Type{$(maketitle(title))}) = StructTypes.Struct()\n\n",
        )
    elseif isnothing(T) && haskey(d, "anyOf")
        # Scalar union definitions do not need their own struct.
        struct_mapping[title] = "Union{$(join(map(x -> parse_type(x, struct_mapping, true)[1], d["anyOf"]), ","))}"
    elseif !isnothing(T)
        struct_mapping[title] = parse_type(d, struct_mapping, true)[1]
    else
        @warn "Unknown type $T for $title"
    end
end


"""Return the canonical CDN URL for a UMM schema spec."""
function schema_url(spec::SchemaSpec)
    "https://cdn.earthdata.nasa.gov/umm/$(spec.family)/$(spec.version)/umm-$(spec.suffix)-json-schema.json"
end

"""Generate one Julia UMM module from a remote JSON Schema."""
function generate_schema(spec::SchemaSpec)
    url = schema_url(spec)
    fn = download(url)
    schema = JSON3.read(read(fn, String))

    # Replace all Symbols with Strings
    sch = todict(schema)
    # Include definitions from sibling schemas referenced by the main schema
    merge_external_definitions!(sch, url)
    # Replace all references with their definitions
    deref!(sch)

    mkpath(dirname(spec.output))
    open(spec.output, "w") do io
        println(io, "# This file is generated from gen/codegen.jl. Do not edit directly.")
        println(io, "module $(spec.module_name)")
        println(io, "using StructTypes")
        println(io, "using ..EarthData: AbstractJSON")
        println(io)
        parse_object(io, sch, Dict{String,String}(), spec)
        println(io, "end")
    end
end

for spec in schemas
    generate_schema(spec)
end

# run JuliaFormatter on the whole package
format(joinpath(@__DIR__, ".."))
