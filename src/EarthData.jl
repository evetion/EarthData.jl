module EarthData

# Write your package code here.
using HTTP
using Dates
using JSON3
using Extents
using StructTypes

include("aws.jl")
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
    collection_concept_id
    granule_ur
    readable_granule_name
    online_only
    downloadable
    browsable
    attribute
    polygon
    equator_crossing_longitude
    equator_crossing_date
    updated_since
    revision_date
    created_at
    production_date
    cloud_cover
    platform
    instrument
    sensor
    project
    concept_id
    echo_granule_id
    echo_collection_id
    day_night_flag
    two_d_coordinate_system
    provider
    native_id
    short_name
    version
    entry_title
    entry_id
    temporal
    cycle
    passes
    sort_key
end


"""
    CollectionRequest(; keyword=value, ...)

As documented by https://cmr.earthdata.nasa.gov/search/site/docs/search/api.html#collection-search-by-parameters.
"""
Base.@kwdef struct CollectionRequest <: AbstractRequest
    concept_id
    doi
    echo_collection_id
    provider_short_name
    entry_title
    entry_id
    archive_center
    data_center
    temporal
    project
    consortium
    updated_since
    created_at
    has_granules_created_at
    has_granules_revised_at
    revision_date
    processing_level_id
    platform
    instrument
    sensor
    spatial_keyword
    science_keywords
    two_d_coordinate_system_name
    collection_data_type
    granule_data_format
    online_only
    downloadable
    browsable
    keyword
    provider
    native_id
    short_name
    version
    tag_key
    variable_name
    variable_native_id
    variable_concept_id
    variables
    service_name
    service_type
    service_concept_id
    tool_name
    tool_type
    tool_concept_id
    polygon
    bounding_box
    point
    line
    circle
    attribute
    author
    has_granules
    has_granules_or_cwic
    has_granules_or_opensearch
    has_opendap_url
    cloud_hosted
    standard_product
    sort_key
    all_revisions
end

struct QueryParams
    page_size
    page_num
    offset
    scroll
    sort_key
    pretty
    token
    echo_compatible
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
        "Something went wrong:\n" * join(get(JSON3.read(r.body), "errors", [""]), "\n")
    catch
        "Something went wrong, but we don't know what."
    end
end

function request(url::AbstractString, query::Dict, T::Type; page_num=1, page_size=10, verbose=false, all=false)
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
    while (length(v) == page_size) &&
              (page_num * page_size) < body.hits &&
              all
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
