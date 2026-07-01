Base.show(io::IO, granule::Granules.UMM_G) = _show_granule(io, granule)
Base.show(io::IO, ::MIME"text/plain", granule::Granules.UMM_G) = show(io, granule)

Base.show(io::IO, collection::Collections.UMM_C) = _show_collection(io, collection)
Base.show(io::IO, ::MIME"text/plain", collection::Collections.UMM_C) = show(io, collection)

function _show_granule(io::IO, granule::Granules.UMM_G)
    prefix = _collection_reference_prefix(granule.CollectionReference)
    isnothing(prefix) ? print(io, granule.GranuleUR) : print(io, prefix, ": ", granule.GranuleUR)
end

function _collection_reference_prefix(reference::Granules.CollectionReferenceType)
    isnothing(reference.ShortName) || return reference.ShortName
    isnothing(reference.EntryTitle) || return reference.EntryTitle
    return nothing
end

function _show_collection(io::IO, collection::Collections.UMM_C)
    print(io, collection.ShortName, ": ", collection.EntryTitle)
end
