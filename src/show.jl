Base.show(io::IO, granule::GranuleSchema.UMM_G) = _show_granule(io, granule)
Base.show(io::IO, ::MIME"text/plain", granule::GranuleSchema.UMM_G) = show(io, granule)

Base.show(io::IO, collection::CollectionSchema.UMM_C) = _show_collection(io, collection)
Base.show(io::IO, ::MIME"text/plain", collection::CollectionSchema.UMM_C) =
    show(io, collection)

function _show_granule(io::IO, granule::GranuleSchema.UMM_G)
    prefix = _collection_reference_prefix(granule.CollectionReference)
    isnothing(prefix) ? print(io, granule.GranuleUR) : print(io, prefix, ": ", granule.GranuleUR)
end

function _collection_reference_prefix(reference::GranuleSchema.CollectionReferenceType)
    isnothing(reference.ShortName) || return reference.ShortName
    isnothing(reference.EntryTitle) || return reference.EntryTitle
    return nothing
end

function _show_collection(io::IO, collection::CollectionSchema.UMM_C)
    print(io, collection.ShortName, ": ", collection.EntryTitle)
end
