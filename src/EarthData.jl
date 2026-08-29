module EarthData

# Write your package code here.
using HTTP
using Dates
using JSON3
using Extents
using StructTypes
import Downloads
import GeoInterface
import Printf
import Base64

include("utils.jl")
include("auth.jl")
abstract type AbstractJSON end
include("umm/granules.jl")
include("umm/collections.jl")
include("display.jl")
include("show.jl")
include("stub.jl")  # empty methods that are actually defined in extensions
include("retry.jl")
include("spatial.jl")
include("temporal.jl")
include("params.jl")
include("geointerface.jl")

const granule_version = "v1.6.6"
const collection_version = "v1.17.0"
const version = granule_version

const granule_umm_json_version = replace(granule_version, "." => "_")
const collection_umm_json_version = replace(collection_version, "." => "_")

"""
    System(; cmr_url, edl_host)

An Earthdata deployment: [`PROD`](@ref) or [`UAT`](@ref).

UAT is where NASA stages a collection before it goes public, so it is what a provider tests
against. Pass one as `system` to [`granules`](@ref) or [`collections`](@ref).

`cmr_url` is a base URL rather than a host, so a proxy or a local CMR can be reached by
constructing a `System` directly. `edl_host` is a bare hostname, since that is what `.netrc`
and curl match on.

!!! note "Search only, for now"
    Nothing reads `edl_host` yet — [`token_from_netrc`](@ref) and [`netrc_credentials`](@ref)
    still target production. A UAT *search* works; UAT *authentication* does not, and a
    production token rejected by UAT reports a production token page.
"""
Base.@kwdef struct System
    cmr_url::String = "https://cmr.earthdata.nasa.gov"
    edl_host::String = "urs.earthdata.nasa.gov"
end

"""
    PROD

The operational Earthdata deployment, and the default for every search.
"""
const PROD = System()

"""
    UAT

Earthdata's user-acceptance-testing deployment, holding staged and pre-release collections.

```julia
granules(short_name="GEDI02_A", system=EarthData.UAT)
```
"""
const UAT = System(
    cmr_url="https://cmr.uat.earthdata.nasa.gov",
    edl_host="uat.urs.earthdata.nasa.gov",
)

search_url(system::System, concept::AbstractString, umm_version::AbstractString) =
    "$(system.cmr_url)/search/$(concept).umm_json_$(umm_version)"

granule_url(system::System=PROD) =
    search_url(system, "granules", granule_umm_json_version)
collection_url(system::System=PROD) =
    search_url(system, "collections", collection_umm_json_version)

abstract type AbstractRequest end

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
    umm::Granules.UMM_G
end
Base.@kwdef struct MetaCollection
    meta::Meta
    umm::Collections.UMM_C
end
Base.@kwdef struct GranuleSearchResponse
    hits::Int
    took::Int
    items::Vector{MetaGranule} = MetaGranule[]
end
Base.@kwdef struct CollectionSearchResponse
    hits::Int
    took::Int
    items::Vector{MetaCollection} = MetaCollection[]
end

StructTypes.StructType(::Type{GranuleSearchResponse}) = StructTypes.Struct()
StructTypes.StructType(::Type{MetaGranule}) = StructTypes.Struct()
StructTypes.StructType(::Type{CollectionSearchResponse}) = StructTypes.Struct()
StructTypes.StructType(::Type{MetaCollection}) = StructTypes.Struct()
responsetype(::Type{Granules.UMM_G}) = GranuleSearchResponse
responsetype(::Type{Collections.UMM_C}) = CollectionSearchResponse

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
    bounding_box::Any
    point::Any
    line::Any
    circle::Any
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
    granules(; keyword=value, ...) -> Vector{Granules.UMM_G}

Search for granules using NASA EarthDataSearch. Possible keywords are
`$(fieldnames(GranuleRequest))` or `$(fieldnames(QueryParams))`.

```jldoctest
g = first(granules(short_name="GEDI02_A"))
startswith(sprint(show, g), "GEDI02_A: ")
# output
true
```
"""
function granules(;
    page_num=1,
    page_size=10,
    verbose=false,
    all=false,
    method=:POST,
    requester=HTTP.request,
    system::System=PROD,
    kwargs...,
)
    d = Dict(kwargs)
    uk = setdiff(keys(d), fieldnames(GranuleRequest), fieldnames(QueryParams))
    isempty(uk) ||
        throw(ArgumentError("Unknown keyword argument(s): " * join(string.(uk), ", ")))
    request(
        granule_url(system),
        Dict(zip(string.(keys(d)), values(d))),
        Granules.UMM_G;
        page_num,
        page_size,
        verbose,
        all,
        method,
        requester,
    )
end

"""
    collections(; keyword=value, ...) -> Vector{Collections.UMM_C}

Search for collections using NASA EarthData Search. Possible keywords are
`$(fieldnames(CollectionRequest))` or `$(fieldnames(QueryParams))`.
"""
function collections(;
    page_num=1,
    page_size=10,
    verbose=false,
    all=false,
    method=:POST,
    requester=HTTP.request,
    system::System=PROD,
    kwargs...,
)
    d = Dict(kwargs)
    uk = setdiff(keys(d), fieldnames(CollectionRequest), fieldnames(QueryParams))
    isempty(uk) ||
        throw(ArgumentError("Unknown keyword argument(s): " * join(string.(uk), ", ")))
    request(
        collection_url(system),
        Dict(zip(string.(keys(d)), values(d))),
        Collections.UMM_C;
        page_num,
        page_size,
        verbose,
        all,
        method,
        requester,
    )
end

function parse_cmr_error(r)
    try
        "Something went wrong: " * join(get(JSON3.read(r.body), "errors", [""]), "\n")
    catch
        "Something went wrong, but we don't know what."
    end
end

function cmr_headers(search_after=nothing)
    headers = ["Client-Id" => "EarthData.jl"]
    isnothing(search_after) || push!(headers, "CMR-Search-After" => search_after)
    return headers
end

"""
    cmr_query(query::Dict; page_num, page_size) -> Vector{Pair{String,Any}}

The wire form of `query`, with each keyword converted by the family it belongs to.

Pairs rather than a `Dict`: `passes` becomes several indexed parameters
(`passes[0][pass]`, `passes[0][tiles]`, `passes[1][pass]`, …) rather than one value, and
`HTTP.URIs.escapeuri` encodes a pair vector correctly where a nested `Dict` collapses to
`passes=0=pass=1`.
"""
function cmr_query(query::Dict; page_num, page_size)
    q = Pair{String,Any}["page_size" => page_size]
    # CMR rejects `page_num` once a `CMR-Search-After` header is in play, so the caller
    # passes `page_num=nothing` for every page after the first.
    isnothing(page_num) || push!(q, "page_num" => page_num)

    # A pass number identifies a granule only within a cycle, so CMR requires exactly one
    # `cycle` alongside and answers "Cycle value must be provided when searching with
    # passes" without it.
    if haskey(query, :passes) || haskey(query, "passes")
        cycle = get(() -> get(query, "cycle", nothing), query, :cycle)
        isnothing(cycle) && throw(
            ArgumentError(
                "`passes` needs a `cycle` as well; a pass number identifies a granule only " *
                "within a cycle.",
            ),
        )
        # CMR: "There can only be one cycle value when searching with passes".
        cycle isa AbstractVector &&
            length(cycle) != 1 &&
            throw(
                ArgumentError(
                    "`passes` allows exactly one `cycle`; got $(length(cycle)).",
                ),
            )
    end

    for (k, v) in query
        isnothing(v) && continue
        sym = Symbol(k)
        append!(q, cmr_pairs(param_family(sym), sym, v))
    end
    return q
end

function header_value(headers, name::AbstractString)
    lname = lowercase(name)
    for (k, v) in headers
        lowercase(String(k)) == lname && return String(v)
    end
    return nothing
end

function cmr_http_request(requester, method, url, headers, query; verbose)
    m = uppercase(String(method))
    if m == "GET"
        return requester(m, url, headers; query, verbose, status_exception=false)
    elseif m == "POST"
        post_headers = copy(headers)
        push!(post_headers, "Content-Type" => "application/x-www-form-urlencoded")
        return requester(
            m,
            url,
            post_headers;
            body=HTTP.URIs.escapeuri(query),
            verbose,
            status_exception=false,
        )
    else
        throw(ArgumentError("Unsupported HTTP method for CMR search: $method"))
    end
end

function request(
    url::AbstractString,
    query::Dict,
    T::Type;
    page_num=1,
    page_size=10,
    verbose=false,
    all=false,
    method=:POST,
    requester=HTTP.request,
)
    q = cmr_query(query; page_num, page_size)
    vv = Vector{T}()
    search_after = nothing
    seen_search_after = Set{String}()

    while true
        r = cmr_http_request(requester, method, url, cmr_headers(search_after), q; verbose)
        HTTP.iserror(r) && error(parse_cmr_error(r))
        body = JSON3.read(r.body, responsetype(T))
        v = map(x -> x.umm, body.items)
        append!(vv, v)
        all || break

        next_search_after = header_value(r.headers, "CMR-Search-After")
        isnothing(next_search_after) && break
        next_search_after in seen_search_after && break
        push!(seen_search_after, next_search_after)
        search_after = next_search_after
        # `page_num` and `CMR-Search-After` are mutually exclusive: sending both makes CMR
        # answer HTTP 400 "page_num is not allowed with search-after", so the first page's
        # `page_num` must be dropped before the second request goes out.
        q = cmr_query(query; page_num=nothing, page_size)
    end
    vv
end

function scheme_prefix(scheme)
    s = string(scheme)
    endswith(s, ":") ? s : s * ":"
end

url_type(u) = hasproperty(u, :Type) ? getproperty(u, :Type) : nothing

"""
    urls(item; scheme=nothing, type=nothing) -> Vector{String}

Related URLs of a UMM record, optionally filtered by URL `scheme` (`:https`, `:s3`) and by
`RelatedUrls[].Type` (`"GET DATA"`, `"GET DATA VIA DIRECT ACCESS"`,
`"VIEW RELATED INFORMATION"`, ...).
"""
function urls(item::AbstractJSON; scheme=nothing, type=nothing)
    related_urls = getproperty(item, :RelatedUrls)
    isnothing(related_urls) && return String[]
    selected = related_urls
    isnothing(type) || (selected = filter(u -> url_type(u) == type, selected))
    result = [u.URL for u in selected]
    isnothing(scheme) && return result
    filter(startswith(scheme_prefix(scheme)), result)
end

function urls(items::AbstractVector{<:AbstractJSON}; scheme=nothing, type=nothing)
    result = String[]
    for item in items
        append!(result, urls(item; scheme, type))
    end
    return result
end

"""
    https_urls(item) -> Vector{String}

The item's related URLs that use the `https` scheme.

Every related URL is returned, not just the data: a DOI landing page, a metadata sidecar
and browse imagery all use `https` too. See [`data_urls`](@ref) when what you want is
something to download.
"""
https_urls(item) = urls(item; scheme=:https)

"""
    s3_urls(item) -> Vector{String}

The item's related URLs that use the `s3` scheme, for direct in-region S3 access.

Reading these requires DAAC-issued temporary credentials and an `AWSS3` session; see
`create_aws_config`. As with [`https_urls`](@ref), the filter is on the scheme alone, so
the result is not necessarily just the data file.
"""
s3_urls(item) = urls(item; scheme=:s3)

"""
    data_urls(item; scheme=:https) -> Vector{String}

URLs of the granule's data file(s), i.e. the related URLs typed `"GET DATA"`.

Records commonly carry several related URLs that are not the data: a DOI landing page, a
metadata sidecar, browse imagery, a cloud-credentials endpoint. Filtering on the scheme
alone does not separate those from the file, so prefer this over [`https_urls`](@ref) when
what you want is something to download. Note the S3 copy of the same file is typed
`"GET DATA VIA DIRECT ACCESS"` and so is *not* returned; use
`urls(item; scheme=:s3, type="GET DATA VIA DIRECT ACCESS")` for that.
"""
data_urls(item; scheme=:https) = urls(item; scheme, type="GET DATA")

function download_url(item; scheme=:https, type=nothing)
    candidates = urls(item; scheme, type)
    isempty(candidates) ? nothing : first(candidates)
end

const size_unit_factors = Dict(
    "BYTES" => 1,
    "B" => 1,
    "KB" => 1024,
    "MB" => 1024^2,
    "GB" => 1024^3,
    "TB" => 1024^4,
)

"""
    size_unit_factor(unit) -> Union{Int,Nothing}

Bytes per `unit`, for the `SizeUnit` values UMM allows (`"Bytes"`, `"KB"`, `"MB"`, `"GB"`,
`"TB"`; binary multiples). Throws for an unrecognised unit rather than guessing, since a
wrong factor silently misreports a size by three orders of magnitude.

`"NA"` returns `nothing`: providers use it to say they recorded no unit, so the accompanying
`Size` cannot be converted at all.
"""
function size_unit_factor(unit::AbstractString)
    key = uppercase(strip(unit))
    key == "NA" && return nothing
    haskey(size_unit_factors, key) ||
        throw(ArgumentError("Unrecognised UMM SizeUnit: $(repr(unit))"))
    return size_unit_factors[key]
end

"""
    granule_size(granule; default_unit="MB") -> Union{Int,Nothing}

Size of a granule in bytes, from `DataGranule.ArchiveAndDistributionInformation`, or
`nothing` when the record does not report one.

`SizeInBytes` is used when present. Otherwise `Size` is converted using its `SizeUnit` —
`Size` is unit-less on its own, and providers do report units other than bytes, so reading
the number without the unit is how a megabyte figure gets mistaken for a byte count. A
record that gives `Size` with no `SizeUnit` is read as `default_unit`, which is what the
DAACs mean in practice; pass `default_unit` explicitly if a provider differs. A `SizeUnit`
of `"NA"` is not a unit, so such an entry is skipped rather than guessed at.

Sizes of multiple files are summed, since together they are the granule.
"""
function granule_size(granule::AbstractJSON; default_unit::AbstractString="MB")
    data_granule = getproperty(granule, :DataGranule)
    isnothing(data_granule) && return nothing
    entries = getproperty(data_granule, :ArchiveAndDistributionInformation)
    isnothing(entries) && return nothing
    total = 0
    found = false
    for entry in entries
        bytes = entry.SizeInBytes
        if isnothing(bytes)
            isnothing(entry.Size) && continue
            factor = size_unit_factor(something(entry.SizeUnit, default_unit))
            isnothing(factor) && continue
            bytes = round(Int, entry.Size * factor)
        end
        total += bytes
        found = true
    end
    return found ? total : nothing
end

function write_urls(
    io::IO,
    items::AbstractVector{<:AbstractJSON};
    scheme=:https,
    type=nothing,
)
    write_urls(io, urls(items; scheme, type))
end

function write_urls(
    fn::AbstractString,
    items::AbstractVector{<:AbstractJSON};
    scheme=:https,
    type=nothing,
)
    write_urls(fn, urls(items; scheme, type))
end

function write_urls(items::AbstractVector{<:AbstractJSON}; scheme=:https, type=nothing)
    write_urls(urls(items; scheme, type))
end

function download(
    items::AbstractVector{<:AbstractJSON},
    folder::AbstractString=".";
    scheme=:https,
    type=nothing,
    kwargs...,
)
    download(urls(items; scheme, type), folder; kwargs...)
end

export granules,
    collections,
    urls,
    https_urls,
    s3_urls,
    data_urls,
    download_url,
    granule_size,
    write_urls,
    download
end
