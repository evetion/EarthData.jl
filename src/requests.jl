"""
The CMR search parameters, as the fields of [`GranuleRequest`](@ref) and
[`CollectionRequest`](@ref).

Each field's type is the set of Julia values that parameter accepts, and its docstring says
what the parameter means. Both are the single description of that parameter: the family
tuples in `params.jl` are derived from the field types, and an error message quotes the field
docstring.

A field holds the *Julia* value, converted only as far as normalizing a `Symbol` or a
`SubString` to a `String`. The conversion to the wire form happens in [`cmr_pairs`](@ref)
when the request is sent, so a request can be inspected in the terms it was written in.

Two kinds of failure are being prevented. CMR validates the boolean, numeric-range and
track parameters and answers a wrong value with an HTTP 400, so converting here turns a
wasted round-trip into an immediate error. The text parameters it does not validate at all —
a value of the wrong shape simply matches nothing — so there the type is what turns a silent
empty result into an error.
"""

"""
    param_names(T::Type) -> Tuple{Vararg{Symbol}}

The parameters typed `T` across both requests, so a family is read off the field types
rather than listed a second time.

`SpatialParam` and `FreeParam` are both `Any` and so are not distinguishable this way; see
`spatial_params`.
"""
param_names(T::Type) = Tuple(
    sort(
        unique(
            n for R in (GranuleRequest, CollectionRequest) for
            n in fieldnames(R) if fieldtype(R, n) === T
        ),
    ),
)

"""
    fielddocs(R::Type) -> Dict{Symbol,Any}

The per-field docstrings of `R`, so an error can say what the parameter means as well as
what it accepts. Empty if the struct carries no docstring, which is where Julia records
them.
"""
function fielddocs(::Type{R}) where {R}
    mod = parentmodule(R)
    binding = Base.Docs.Binding(mod, nameof(R))
    meta = Base.Docs.meta(mod)
    haskey(meta, binding) || return Dict{Symbol,Any}()
    for doc in values(meta[binding].docs)
        haskey(doc.data, :fields) && return doc.data[:fields]
    end
    return Dict{Symbol,Any}()
end

# What a field accepts, read off its type so the message cannot drift from the declaration.
# `Nothing` is dropped: omitting the keyword is not one of the values to pass.
function accepted_types(::Type{R}, name::Symbol) where {R}
    members = filter(!=(Nothing), Base.uniontypes(fieldtype(R, name)))
    isempty(members) && return "a value"
    return join(string.(members), ", ", " or ")
end

"""
    convert_field(R::Type, name::Symbol, value)

`value` as the `name` field of request `R`, or an `ArgumentError` naming the field and
quoting its docstring.

The field name is not an argument of `Base.convert`, which receives only the field type and
the value, so naming the parameter has to happen here rather than in [`cmr_convert`](@ref) —
whose methods describe a family shared by many fields.
"""
function convert_field(::Type{R}, name::Symbol, value) where {R<:AbstractRequest}
    isnothing(value) && return nothing
    # The spatial parameters share one field type, so they convert by name and phrase their
    # own errors — a geometry is wrong for the keyword rather than for the type.
    name in spatial_params && return cmr_spatial(name, value)
    try
        return cmr_convert(fieldtype(R, name), value)
    catch e
        e isa ArgumentError || e isa MethodError || rethrow()
        reason =
            e isa ArgumentError ? e.msg :
            "takes $(accepted_types(R, name)); got $(typeof(value))."
        doc = get(fielddocs(R), name, nothing)
        throw(
            ArgumentError(
                "`$(name)` $(reason)" * (isnothing(doc) ? "" : "\n$(name): $(doc)"),
            ),
        )
    end
end

"""
    GranuleRequest(; keyword=value, ...)

A granule search. Every field is a CMR granule search parameter, as documented at
https://cmr.earthdata.nasa.gov/search/site/docs/search/api.html#granule-search-by-parameters.

Built by [`granules`](@ref) from its keywords; each field's type is what that parameter
accepts, and omitting one searches without filtering on it.
"""
Base.@kwdef struct GranuleRequest <: AbstractRequest
    "Concept ID of the granule's parent collection, e.g. `\"C1234567-PODAAC\"`."
    collection_concept_id::TextParam = nothing
    "The granule's UR, its unique identifier within the provider."
    granule_ur::TextParam = nothing
    "The granule's producer granule ID."
    readable_granule_name::TextParam = nothing
    "Restrict to granules with a download link. A legacy alias of `downloadable`."
    online_only::BoolParam = nothing
    "Restrict to granules carrying a `GET DATA` related URL."
    downloadable::BoolParam = nothing
    "Restrict to granules carrying a `GET RELATED VISUALIZATION` related URL."
    browsable::BoolParam = nothing
    """
    An additional attribute, as `type,name,value`.

    CMR requires a nested `attribute[]` key. This package sends `attribute=`, which CMR
    rejects: "'attribute' is not a valid parameter".
    """
    attribute::FreeParam = nothing
    "A polygon: a GeoInterface polygon or ring, closed and wound counter-clockwise for CMR."
    polygon::SpatialParam = nothing
    "A bounding box: an `Extent`, or `west,south,east,north`."
    bounding_box::SpatialParam = nothing
    "A point: a GeoInterface point, or `(lon, lat)`."
    point::SpatialParam = nothing
    "A line: a GeoInterface line or line string."
    line::SpatialParam = nothing
    "A circle: `(lon, lat, radius_m)`, or `(point, radius_m)`. Radius is in metres."
    circle::SpatialParam = nothing
    "Longitude at which the orbit crosses the equator, as a `(min, max)` range."
    equator_crossing_longitude::NumericRangeParam = nothing
    "When the orbit crossed the equator."
    equator_crossing_date::DateRangeParam = nothing
    "Granules whose revision date is at or after this instant. A single date, not a range."
    updated_since::DateParam = nothing
    "When the granule's metadata was last revised."
    revision_date::DateRangeParam = nothing
    "When the granule was created."
    created_at::DateRangeParam = nothing
    "When the granule was produced."
    production_date::DateRangeParam = nothing
    """
    Fraction of the granule covered by cloud, as a `(min, max)` range.

    CMR does not bound this to 0–100, so neither does this package.
    """
    cloud_cover::NumericRangeParam = nothing
    "Platform short name, e.g. `\"Terra\"`. Inherited from the parent collection if unset."
    platform::TextParam = nothing
    "Instrument short name, e.g. `\"MODIS\"`."
    instrument::TextParam = nothing
    "Sensor short name. Deprecated by CMR in favor of `instrument`."
    sensor::TextParam = nothing
    "Project (campaign) short name."
    project::TextParam = nothing
    "The granule's concept ID, e.g. `\"G1234567-PODAAC\"`. A collection ID also works here."
    concept_id::TextParam = nothing
    "The granule's ECHO ID. Interchangeable with a granule `concept_id`."
    echo_granule_id::TextParam = nothing
    "The parent collection's ECHO ID. Interchangeable with `collection_concept_id`."
    echo_collection_id::TextParam = nothing
    """
    Whether the granule was collected in daylight: `\"DAY\"`, `\"NIGHT\"`, `\"BOTH\"`.

    CMR pattern-matches this rather than validating it against those three, so a value
    outside them returns no granules rather than an error.
    """
    day_night_flag::TextParam = nothing
    """
    A two-dimensional tiling system and coordinates, as `name:coords`.

    Structured, so it is passed on as written: `\"MODIS Tile EASE:2:3\"`.
    """
    two_d_coordinate_system::FreeParam = nothing
    "The provider holding the granule, e.g. `\"NSIDC_CPRD\"`."
    provider::TextParam = nothing
    "The granule's native ID within its provider."
    native_id::TextParam = nothing
    "Short name of the parent collection, e.g. `\"MCD43A3\"`."
    short_name::TextParam = nothing
    """
    Version of the parent collection.

    Matched literally and zero-padded, so this must be a string: `version=\"061\"` finds
    MCD43A3, while `061` is the integer `61` in Julia and finds nothing.
    """
    version::TextParam = nothing
    "Entry title of the parent collection."
    entry_title::TextParam = nothing
    "Entry ID of the parent collection: its short name, an underscore, and its version."
    entry_id::TextParam = nothing
    "When the granule was observed, as a date or a `(start, stop)` range."
    temporal::DateRangeParam = nothing
    "Orbital cycle, a positive integer. Required alongside `passes`, and then only one."
    cycle::PositiveIntParam = nothing
    """
    Orbital pass, as a number or a [`Pass`](@ref) naming its tiles.

    Needs exactly one `cycle` as well, since a pass number identifies a granule only within
    a cycle.
    """
    passes::PassesParam = nothing
    "Field to sort the results by; `-` reverses it, as in `\"-start_date\"`."
    sort_key::TextParam = nothing

    function GranuleRequest(args...)
        names = fieldnames(GranuleRequest)
        request = new(
            ntuple(i -> convert_field(GranuleRequest, names[i], args[i]), length(names))...,
        )
        check_track(request)
        return request
    end
end

"""
    check_track(request::GranuleRequest)

Check `passes` against `cycle`. A pass number identifies a granule only within a cycle, so
CMR requires exactly one `cycle` alongside and otherwise answers "Cycle value must be
provided when searching with passes".
"""
function check_track(request::GranuleRequest)
    isnothing(request.passes) && return nothing
    cycle = request.cycle
    isnothing(cycle) && throw(
        ArgumentError(
            "`passes` needs a `cycle` as well; a pass number identifies a granule only " *
            "within a cycle.",
        ),
    )
    # CMR: "There can only be one cycle value when searching with passes".
    cycle isa AbstractVector &&
        length(cycle) != 1 &&
        throw(ArgumentError("`passes` allows exactly one `cycle`; got $(length(cycle))."))
    return nothing
end

"""
    CollectionRequest(; keyword=value, ...)

A collection search. Every field is a CMR collection search parameter, as documented at
https://cmr.earthdata.nasa.gov/search/site/docs/search/api.html#collection-search-by-parameters.

Built by [`collections`](@ref) from its keywords; each field's type is what that parameter
accepts, and omitting one searches without filtering on it.
"""
Base.@kwdef struct CollectionRequest <: AbstractRequest
    "The collection's concept ID, e.g. `\"C1234567-LPDAAC_ECS\"`."
    concept_id::TextParam = nothing
    "The collection's DOI, e.g. `\"10.5067/MODIS/MCD43A3.061\"`."
    doi::TextParam = nothing
    "The collection's ECHO ID. Interchangeable with `concept_id`."
    echo_collection_id::TextParam = nothing
    "Short name of the provider holding the collection."
    provider_short_name::TextParam = nothing
    "The collection's entry title, its long human-readable name."
    entry_title::TextParam = nothing
    "The collection's entry ID: its short name, an underscore, and its version."
    entry_id::TextParam = nothing
    "Short name of the archive center, e.g. `\"NSIDC\"`."
    archive_center::TextParam = nothing
    "Short name of a data center associated with the collection."
    data_center::TextParam = nothing
    "The collection's temporal extent, as a date or a `(start, stop)` range."
    temporal::DateRangeParam = nothing
    "Project (campaign) short name."
    project::TextParam = nothing
    "A consortium the collection belongs to, e.g. `\"CWIC\"`, `\"EOSDIS\"`."
    consortium::TextParam = nothing
    "Collections whose revision date is at or after this instant. A single date, not a range."
    updated_since::DateParam = nothing
    "When the collection was created."
    created_at::DateRangeParam = nothing
    "Collections that gained a granule within this range."
    has_granules_created_at::DateRangeParam = nothing
    "Collections whose granules were created or updated within this range."
    has_granules_revised_at::DateRangeParam = nothing
    "When the collection's metadata was last revised."
    revision_date::DateRangeParam = nothing
    """
    Processing level, e.g. `\"1B\"`, `\"2G\"`, `2`.

    Stored as the bare digits and not zero-padded, so a number is a valid value here — `2`
    matches where `\"02\"` does not. Unlike `version`, this is not a [`TextParam`](@ref).
    """
    processing_level_id::FreeParam = nothing
    "Platform short name, e.g. `\"Terra\"`."
    platform::TextParam = nothing
    "Instrument short name, e.g. `\"MODIS\"`."
    instrument::TextParam = nothing
    "Sensor short name. Deprecated by CMR in favor of `instrument`."
    sensor::TextParam = nothing
    "A spatial keyword, e.g. `\"Greenland\"`."
    spatial_keyword::TextParam = nothing
    """
    A science keyword, by its `category`, `topic`, `term` or variable level.

    CMR requires a nested `science_keywords[]` key. This package sends
    `science_keywords=`, which CMR rejects: "Parameter [science_keywords] must include a
    nested key".
    """
    science_keywords::FreeParam = nothing
    """
    Name of the collection's two-dimensional tiling system.

    CMR's values include `\"MODIS Tile EASE\"`, `\"MODIS Tile SIN\"`, `\"WRS-1\"`,
    `\"WRS-2\"`, `\"CALIPSO\"`, `\"MISR\"` and `\"Military Grid Reference System\"`.
    """
    two_d_coordinate_system_name::TextParam = nothing
    "Collection data type, e.g. `\"SCIENCE_QUALITY\"`, `\"NEAR_REAL_TIME\"`."
    collection_data_type::TextParam = nothing
    "Format of the data in the collection's granules, e.g. `\"HDF5\"`, `\"netCDF-4\"`."
    granule_data_format::TextParam = nothing
    "Restrict to downloadable collections. A legacy alias of `downloadable`."
    online_only::BoolParam = nothing
    "Restrict to collections with at least one `GET DATA` distribution URL."
    downloadable::BoolParam = nothing
    "Restrict to collections with at least one visualization URL."
    browsable::BoolParam = nothing
    """
    Free-text search across the collection's metadata.

    Case-insensitive, and supports the wildcards `*` and `?`.
    """
    keyword::TextParam = nothing
    "The provider holding the collection, e.g. `\"LPDAAC_ECS\"`."
    provider::TextParam = nothing
    "The collection's native ID within its provider."
    native_id::TextParam = nothing
    "The collection's short name, e.g. `\"MCD43A3\"`."
    short_name::TextParam = nothing
    """
    The collection's version.

    Matched literally and zero-padded, so this must be a string: `version=\"061\"` finds
    MCD43A3, while `061` is the integer `61` in Julia and finds nothing.
    """
    version::TextParam = nothing
    "A tag key associated with the collection."
    tag_key::TextParam = nothing
    "Name of a variable associated with the collection."
    variable_name::TextParam = nothing
    "Native ID of a variable associated with the collection."
    variable_native_id::TextParam = nothing
    "Concept ID of a variable associated with the collection."
    variable_concept_id::TextParam = nothing
    """
    Hierarchical variable search.

    CMR rejects this: "Parameter [variables] was not recognized". Search by
    `variable_name` instead.
    """
    variables::FreeParam = nothing
    "Name of a service associated with the collection."
    service_name::TextParam = nothing
    "Type of a service associated with the collection, e.g. `\"Harmony\"`."
    service_type::TextParam = nothing
    "Concept ID of a service associated with the collection."
    service_concept_id::TextParam = nothing
    "Name of a tool associated with the collection."
    tool_name::TextParam = nothing
    "Type of a tool associated with the collection, e.g. `\"Downloadable Tool\"`."
    tool_type::TextParam = nothing
    "Concept ID of a tool associated with the collection."
    tool_concept_id::TextParam = nothing
    "A polygon: a GeoInterface polygon or ring, closed and wound counter-clockwise for CMR."
    polygon::SpatialParam = nothing
    "A bounding box: an `Extent`, or `west,south,east,north`."
    bounding_box::SpatialParam = nothing
    "A point: a GeoInterface point, or `(lon, lat)`."
    point::SpatialParam = nothing
    "A line: a GeoInterface line or line string."
    line::SpatialParam = nothing
    "A circle: `(lon, lat, radius_m)`, or `(point, radius_m)`. Radius is in metres."
    circle::SpatialParam = nothing
    """
    An additional attribute, as `type,name,value`.

    CMR requires a nested `attribute[]` key. This package sends `attribute=`, which CMR
    rejects: "'attribute' is not a valid parameter".
    """
    attribute::FreeParam = nothing
    "An author of the collection."
    author::TextParam = nothing
    "Restrict to collections that have granules, or to those that do not."
    has_granules::BoolParam = nothing
    "As `has_granules`, but also keeps collections in the CWIC consortium."
    has_granules_or_cwic::BoolParam = nothing
    "As `has_granules`, but also keeps collections in any OpenSearch consortium."
    has_granules_or_opensearch::BoolParam = nothing
    "Restrict to collections with an OPeNDAP service URL."
    has_opendap_url::BoolParam = nothing
    "Restrict to collections held in the cloud, i.e. with direct S3 distribution."
    cloud_hosted::BoolParam = nothing
    "Restrict to collections marked as a standard product."
    standard_product::BoolParam = nothing
    "Field to sort the results by; `-` reverses it, as in `\"-start_date\"`."
    sort_key::TextParam = nothing
    "Return every revision of each collection, rather than only the latest."
    all_revisions::BoolParam = nothing

    function CollectionRequest(args...)
        names = fieldnames(CollectionRequest)
        return new(
            ntuple(
                i -> convert_field(CollectionRequest, names[i], args[i]),
                length(names),
            )...,
        )
    end
end

"""
    QueryParams

CMR's paging and formatting parameters, which are not search filters. Accepted by
[`granules`](@ref) and [`collections`](@ref) alongside the search keywords.
"""
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

"""
    build_request(R::Type; kwargs...) -> R

The request `kwargs` describe, with a misspelled keyword named rather than listed among all
of `R`'s fields, which is what `Base.@kwdef`'s own `MethodError` would do.

A [`QueryParams`](@ref) keyword is accepted and dropped here: it is a paging parameter rather
than a search filter, and `request` adds those itself.
"""
function build_request(::Type{R}; kwargs...) where {R<:AbstractRequest}
    unknown = setdiff(keys(kwargs), fieldnames(R), fieldnames(QueryParams))
    isempty(unknown) || throw(
        ArgumentError(
            "Unknown keyword argument(s): " *
            join(string.(unknown), ", ") *
            ". See `fieldnames(EarthData.$(nameof(R)))` for the parameters $(nameof(R)) " *
            "accepts.",
        ),
    )
    return R(; filter(kw -> first(kw) in fieldnames(R), pairs(kwargs))...)
end

"""
    cmr_query(request::AbstractRequest; page_num, page_size) -> Vector{Pair{String,Any}}

The wire form of `request`: every field that is set, converted by its type.

Pairs rather than a `Dict`, since `passes` becomes several indexed parameters
(`passes[0][pass]`, `passes[0][tiles]`, …) rather than one value, and `HTTP.URIs.escapeuri`
encodes a pair vector correctly where a nested `Dict` collapses to `passes=0=pass=1`.
"""
function cmr_query(request::AbstractRequest; page_num, page_size)
    query = Pair{String,Any}["page_size" => page_size]
    # CMR rejects `page_num` once a `CMR-Search-After` header is in play, so the caller
    # passes `page_num=nothing` for every page after the first.
    isnothing(page_num) || push!(query, "page_num" => page_num)

    for name in fieldnames(typeof(request))
        value = getfield(request, name)
        isnothing(value) || append!(query, cmr_pairs(name, value))
    end
    return query
end
