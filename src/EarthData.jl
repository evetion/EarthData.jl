module EarthData

# Write your package code here.
using HTTP
using Dates
using JSON3
using Extents
using StructTypes

include("utils.jl")
include("granuletypes.jl")
include("display.jl")

const world = Extent(X=(-180.0, 180.0), Y=(-90.0, 90.0))

const version = "v1.6.4"

const umm_json_version = replace(version, "." => "_")
const granule_url = "https://cmr.earthdata.nasa.gov/search/granules.umm_json_$umm_json_version"
const collection_url = "https://cmr.earthdata.nasa.gov/search/collections.umm_json_$umm_json_version"

abstract type AbstractRequest end

const Granule = UMM_G

struct Meta
    var"concept-type"::String
    var"concept-id"::String
    var"revision-id"::Int
    var"native-id"::String
    var"provider-id"::String
    format::String
    var"revision-date"::String
end

Base.@kwdef struct MetaGranule
    meta::Meta
    umm::Granule
end
Base.@kwdef struct Granules
    hits::Int
    took::Int
    items::Vector{MetaGranule} = MetaGranule[]
end

StructTypes.StructType(::Type{Granules}) = StructTypes.Struct()
StructTypes.StructType(::Type{MetaGranule}) = StructTypes.Struct()
responsetype(::Type{Granule}) = Granules

"""
    GranuleRequest(; keyword=value, ...)

As documented by https://cmr.earthdata.nasa.gov/search/site/docs/search/api.html#granule-search-by-parameters.
See `fieldnames(GranuleRequest)` for a list of all possible keywords.
"""
Base.@kwdef struct GranuleRequest <: AbstractRequest
    collection_concept_id::Any
    granule_ur::Any
    readable_granule_name::Any
    online_only::Any
    downloadable::Any
    browsable::Any
    attribute::Any
    polygon::Any
    equator_crossing_longitude::Any
    equator_crossing_date::Any
    updated_since::Any
    revision_date::Any
    created_at::Any
    production_date::Any
    cloud_cover::Any
    platform::Any
    instrument::Any
    sensor::Any
    project::Any
    concept_id::Any
    echo_granule_id::Any
    echo_collection_id::Any
    day_night_flag::Any
    two_d_coordinate_system::Any
    provider::Any
    native_id::Any
    short_name::Any
    version::Any
    entry_title::Any
    entry_id::Any
    temporal::Any
    cycle::Any
    passes::Any
    sort_key::Any
end


"""
    CollectionRequest(; keyword=value, ...)

As documented by https://cmr.earthdata.nasa.gov/search/site/docs/search/api.html#collection-search-by-parameters.
"""
Base.@kwdef struct CollectionRequest <: AbstractRequest
    concept_id::Any
    doi::Any
    echo_collection_id::Any
    provider_short_name::Any
    entry_title::Any
    entry_id::Any
    archive_center::Any
    data_center::Any
    temporal::Any
    project::Any
    consortium::Any
    updated_since::Any
    created_at::Any
    has_granules_created_at::Any
    has_granules_revised_at::Any
    revision_date::Any
    processing_level_id::Any
    platform::Any
    instrument::Any
    sensor::Any
    spatial_keyword::Any
    science_keywords::Any
    two_d_coordinate_system_name::Any
    collection_data_type::Any
    granule_data_format::Any
    online_only::Any
    downloadable::Any
    browsable::Any
    keyword::Any
    provider::Any
    native_id::Any
    short_name::Any
    version::Any
    tag_key::Any
    variable_name::Any
    variable_native_id::Any
    variable_concept_id::Any
    variables::Any
    service_name::Any
    service_type::Any
    service_concept_id::Any
    tool_name::Any
    tool_type::Any
    tool_concept_id::Any
    polygon::Any
    bounding_box::Any
    point::Any
    line::Any
    circle::Any
    attribute::Any
    author::Any
    has_granules::Any
    has_granules_or_cwic::Any
    has_granules_or_opensearch::Any
    has_opendap_url::Any
    cloud_hosted::Any
    standard_product::Any
    sort_key::Any
    all_revisions::Any
end

struct QueryParams
    page_size::Any
    page_num::Any
    offset::Any
    scroll::Any
    sort_key::Any
    pretty::Any
    token::Any
    echo_compatible::Any
end

# function search(g::GranuleRequest)::Vector{Granule}
#     granules(Dict(g)...)
# end

# function search(c::CollectionRequest)::Vector{Collection}
#     collections(Dict(c)...)
# end

"""
    granules(; keyword=value, ...) -> Vector{Granule}

Search for granules using NASA EarthDataSearch. Possible keywords are
`$(fieldnames(GranuleRequest))` or `$(fieldnames(QueryParams))`.

```jldoctest
granules(short_name="GEDI02_A")
# output
10-element Vector{EarthData.UMM_G}:
 EarthData.UMM_G
 EarthData.UMM_G
 EarthData.UMM_G
 EarthData.UMM_G
 EarthData.UMM_G
 EarthData.UMM_G
 EarthData.UMM_G
 EarthData.UMM_G
 EarthData.UMM_G
 EarthData.UMM_G
```
"""
function granules(; kwargs...)
    d = Dict(kwargs)
    uk = setdiff(keys(d), fieldnames(GranuleRequest), fieldnames(QueryParams))
    isempty(uk) || throw(ArgumentError("Unknown keyword argument(s): " * join(uk, ", ")))
    request(granule_url, Dict(zip(string.(keys(d)), values(d))), Granule)
end

function parse_cmr_error(r)
    try
        "Something went wrong: " * join(get(JSON3.read(r.body), "errors", [""]), "\n")
    catch
        "Something went wrong, but we don't know what."
    end
end

function request(
    url::AbstractString,
    query::Dict,
    T::Type;
    page_num=1,
    page_size=10,
    verbose=false,
    all=false
)
    q = Dict{String,String}(
        "page_num" => string(page_num),
        "page_size" => string(page_size),
    )
    q = merge!(q, query)
    headers = ["Client-Id" => "EarthData.jl"]
    r = HTTP.get(url, headers, query=q, verbose=verbose, status_exception=false)
    HTTP.iserror(r) && error(parse_cmr_error(r))
    body = JSON3.read(r.body, responsetype(T))
    v = map(x -> x.umm, body.items)
    vv = Vector{T}()
    append!(vv, v)
    while (length(v) == page_size) && (page_num * page_size) < body.hits && all
        q["page_num"] += 1
        r = HTTP.get(qurl, query=q, verbose=verbose, status_exception=false)
        HTTP.iserror(r) && error(parse_cmr_error(r))
        body = JSON3.read(r.body, responsetype(T))
        v = map(x -> x.umm, body.items)
        append!(vv, v)
    end
    vv
end

export granules
end
