"""
CMR's `meta` block for a granule: the record's identity and revision, none of which the
UMM-G document itself carries.

`collection_concept_id` addresses the granule's collection, which is how a granule reaches
collection-level metadata such as `DirectDistributionInformation`.

Field names are snake_case where CMR sends kebab-case; `StructTypes.names` carries the
mapping.
"""
struct GranuleMeta
    concept_type::String
    concept_id::String
    collection_concept_id::String
    revision_id::Int
    native_id::String
    provider_id::String
    format::String
    revision_date::String
end

"""
CMR's `meta` block for a collection.

Larger than [`GranuleMeta`](@ref) and disjoint from it: a collection carries the `has_*`
service capabilities and `s3_links`, and has no `collection_concept_id` of its own.

`associations` and `s3_links` are absent from many records, so both are nullable.

CMR also sends `association-details`, which is not read: every entry it carries holds a
single `concept-id`, which is what `associations` already lists.
"""
struct CollectionMeta
    concept_type::String
    concept_id::String
    revision_id::Int
    native_id::String
    provider_id::String
    user_id::String
    format::String
    revision_date::String
    deleted::Bool
    has_combine::Bool
    has_formats::Bool
    has_spatial_subsetting::Bool
    has_temporal_subsetting::Bool
    has_transforms::Bool
    has_variables::Bool
    s3_links::Union{Nothing,Vector{String}}
    associations::Union{Nothing,Dict{String,Vector{String}}}
end

StructTypes.names(::Type{GranuleMeta}) = (
    (:concept_type, Symbol("concept-type")),
    (:concept_id, Symbol("concept-id")),
    (:collection_concept_id, Symbol("collection-concept-id")),
    (:revision_id, Symbol("revision-id")),
    (:native_id, Symbol("native-id")),
    (:provider_id, Symbol("provider-id")),
    (:revision_date, Symbol("revision-date")),
)

StructTypes.names(::Type{CollectionMeta}) = (
    (:concept_type, Symbol("concept-type")),
    (:concept_id, Symbol("concept-id")),
    (:revision_id, Symbol("revision-id")),
    (:native_id, Symbol("native-id")),
    (:provider_id, Symbol("provider-id")),
    (:user_id, Symbol("user-id")),
    (:revision_date, Symbol("revision-date")),
    (:has_combine, Symbol("has-combine")),
    (:has_formats, Symbol("has-formats")),
    (:has_spatial_subsetting, Symbol("has-spatial-subsetting")),
    (:has_temporal_subsetting, Symbol("has-temporal-subsetting")),
    (:has_transforms, Symbol("has-transforms")),
    (:has_variables, Symbol("has-variables")),
    (:s3_links, Symbol("s3-links")),
)

Base.@kwdef struct MetaGranule
    meta::GranuleMeta
    umm::Granules.UMM_G
end
Base.@kwdef struct MetaCollection
    meta::CollectionMeta
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

StructTypes.StructType(::Type{GranuleMeta}) = StructTypes.Struct()
StructTypes.StructType(::Type{CollectionMeta}) = StructTypes.Struct()
StructTypes.StructType(::Type{GranuleSearchResponse}) = StructTypes.Struct()
StructTypes.StructType(::Type{MetaGranule}) = StructTypes.Struct()
StructTypes.StructType(::Type{CollectionSearchResponse}) = StructTypes.Struct()
StructTypes.StructType(::Type{MetaCollection}) = StructTypes.Struct()

# The response envelope a concept's records arrive in, so `request` can parse a body
# knowing only the record type it was asked for.
responsetype(::Type{Granules.UMM_G}) = GranuleSearchResponse
responsetype(::Type{Collections.UMM_C}) = CollectionSearchResponse
