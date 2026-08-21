"""
`Extents.extent` for UMM records, so a search result can constrain the rest of the
ecosystem: `Rasters.crop(raster; to=Extents.extent(granule))`, `GeometryOps`, or another
search.

A granule states its coverage as any of `BoundingRectangles`, `GPolygons`, `Points` or
`Lines`, and may carry several; the result is the extent enclosing all of them. `Ti` comes
from the `TemporalExtent`, which is either a range or a single instant.
"""

# CMR reports times as ISO 8601 with a `Z` and sometimes milliseconds, neither of which
# `DateTime`'s parser accepts, so read only the leading `yyyy-mm-ddTHH:MM:SS`. An
# unparseable value is skipped rather than guessed at; `tryparse` already returns `nothing`
# for an empty or blank string. Sub-second precision is dropped, which no extent needs.
umm_datetime(s::AbstractString) =
    tryparse(DateTime, SubString(s, 1, min(lastindex(s), 19)))
umm_datetime(::Nothing) = nothing

point_extent(p) = Extent(X=(p.Longitude, p.Longitude), Y=(p.Latitude, p.Latitude))

# Fold rather than `reduce` over a lazy generator: `reduce` without an `init` cannot infer
# the `Extent` type parameters, so every intermediate boxes — 192 KB for a 1000-point
# boundary. `nothing` is the empty accumulator, since `Extents.union` already absorbs it but
# cannot start from it.
grow_extent(acc, ::Nothing) = acc
grow_extent(::Nothing, ext) = ext
grow_extent(acc, ext) = Extents.union(acc, ext)

function points_extent(points)
    acc = nothing
    for p in points
        acc = grow_extent(acc, point_extent(p))
    end
    return acc
end

# The geometry helpers are deliberately untyped: `Granules` and `Collections` generate
# field-identical `BoundingRectangleType`/`PointType`/`LineType`/`GPolygonType`, so the same
# walk serves both and `Extents.extent(::UMM_C)` needs only its own top-level method.
geometry_extent(r) = Extent(
    X=(r.WestBoundingCoordinate, r.EastBoundingCoordinate),
    Y=(r.SouthBoundingCoordinate, r.NorthBoundingCoordinate),
)

# Dispatch on the field a geometry carries rather than on its module-qualified type.
geometry_extent(p::Union{Granules.GPolygonType,Collections.GPolygonType}) =
    points_extent(p.Boundary.Points)  # An ExclusiveZone is a hole inside, so it cannot widen.
geometry_extent(l::Union{Granules.LineType,Collections.LineType}) = points_extent(l.Points)
geometry_extent(p::Union{Granules.PointType,Collections.PointType}) = point_extent(p)

function geometries_extent(geometry)
    acc = nothing
    for collection in
        (geometry.BoundingRectangles, geometry.GPolygons, geometry.Points, geometry.Lines)
        isnothing(collection) && continue
        for g in collection
            acc = grow_extent(acc, geometry_extent(g))
        end
    end
    return acc
end

function spatial_extent(record)
    spatial = @something record.SpatialExtent return nothing
    horizontal = @something spatial.HorizontalSpatialDomain return nothing
    return geometries_extent(@something horizontal.Geometry return nothing)
end

function temporal_extent(granule::Granules.UMM_G)
    temporal = @something granule.TemporalExtent return nothing
    range = temporal.RangeDateTime
    isnothing(range) && return instant_extent(umm_datetime(temporal.SingleDateTime))
    # An open-ended granule is bounded by whichever end it does state.
    bounds = filter(
        !isnothing,
        (umm_datetime(range.BeginningDateTime), umm_datetime(range.EndingDateTime)),
    )
    isempty(bounds) && return nothing
    return (first(bounds), last(bounds))
end

instant_extent(::Nothing) = nothing
instant_extent(instant::DateTime) = (instant, instant)

"""
    Extents.extent(granule::Granules.UMM_G) -> Union{Extent,Nothing}

The granule's bounding extent, with `X`/`Y` in degrees and `Ti` from its temporal coverage,
or `nothing` when the record states no coverage at all.

`X`/`Y` enclose every geometry the record carries — CMR states coverage as bounding
rectangles, polygons, points or lines, and a granule may hold more than one. A key is
present only if the record supports it, so test with `haskey` before reading. Consumers with
no time dimension ignore `Ti`; `Rasters` warns when cropping a purely spatial raster with
one, so pass only the keys you need.

`Extents` is not re-exported, so reach it either with `using Extents` or, as here, through
`EarthData.Extents`.

```jldoctest
g = first(granules(short_name="GEDI02_A"))
ext = EarthData.Extents.extent(g);
haskey(ext, :X) && haskey(ext, :Ti)
# output
true
```
"""
function Extents.extent(granule::Granules.UMM_G)
    spatial = spatial_extent(granule)
    temporal = temporal_extent(granule)
    isnothing(temporal) && return spatial
    # `Extent(; NamedTuple()..., Ti=t)` is `Extent(Ti=t)`, so the spatial-less case needs no
    # branch of its own.
    bounds = isnothing(spatial) ? NamedTuple() : Extents.bounds(spatial)
    return Extent(; bounds..., Ti=temporal)
end
