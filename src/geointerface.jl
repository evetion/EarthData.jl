"""
GeoInterface for the UMM geometry types, so a search result's coverage is a geometry like
any other: `Extents.extent(granule)`, `GeometryOps`, `Rasters.crop`, or plotting.

CMR states coverage as `BoundingRectangles`, `GPolygons`, `Points` or `Lines`, and a record
may carry several kinds at once, so `GeometryType` is a geometry collection. Implementing
the traits also makes these types valid search inputs, since [`cmr_spatial`](@ref) already
dispatches on them.

`Granules` and `Collections` generate field-identical geometry structs, so each method takes
the `Union` of both and one implementation serves granules and collections alike.
"""

const UMMPoint = Union{Granules.PointType,Collections.PointType}
const UMMLine = Union{Granules.LineType,Collections.LineType}
const UMMBoundary = Union{Granules.BoundaryType,Collections.BoundaryType}
const UMMRectangle =
    Union{Granules.BoundingRectangleType,Collections.BoundingRectangleType}
const UMMPolygon = Union{Granules.GPolygonType,Collections.GPolygonType}
const UMMGeometry = Union{Granules.GeometryType,Collections.GeometryType}

GeoInterface.isgeometry(::Type{<:UMMPoint}) = true
GeoInterface.geomtrait(::UMMPoint) = GeoInterface.PointTrait()
GeoInterface.ncoord(::GeoInterface.PointTrait, ::UMMPoint) = 2
GeoInterface.getcoord(::GeoInterface.PointTrait, p::UMMPoint, i) =
    i == 1 ? p.Longitude : p.Latitude
GeoInterface.x(::GeoInterface.PointTrait, p::UMMPoint) = p.Longitude
GeoInterface.y(::GeoInterface.PointTrait, p::UMMPoint) = p.Latitude

# A UMM `Line` is a connected sequence of points, which is a line string rather than the
# two-point `LineTrait`.
GeoInterface.isgeometry(::Type{<:UMMLine}) = true
GeoInterface.geomtrait(::UMMLine) = GeoInterface.LineStringTrait()
GeoInterface.ncoord(::GeoInterface.LineStringTrait, ::UMMLine) = 2
GeoInterface.ngeom(::GeoInterface.LineStringTrait, l::UMMLine) = length(l.Points)
GeoInterface.getgeom(::GeoInterface.LineStringTrait, l::UMMLine, i) = l.Points[i]

# UMM requires a boundary to be closed and counter-clockwise, which is a linear ring.
GeoInterface.isgeometry(::Type{<:UMMBoundary}) = true
GeoInterface.geomtrait(::UMMBoundary) = GeoInterface.LinearRingTrait()
GeoInterface.ncoord(::GeoInterface.LinearRingTrait, ::UMMBoundary) = 2
GeoInterface.ngeom(::GeoInterface.LinearRingTrait, b::UMMBoundary) = length(b.Points)
GeoInterface.getgeom(::GeoInterface.LinearRingTrait, b::UMMBoundary, i) = b.Points[i]

# An `ExclusiveZone` is a set of boundaries excluded from the main one, so its boundaries are
# the polygon's holes: ring 1 is the exterior and rings 2+ are holes, which is the order
# GeoInterface's `getexterior`/`gethole` fallbacks index.
GeoInterface.isgeometry(::Type{<:UMMPolygon}) = true
GeoInterface.geomtrait(::UMMPolygon) = GeoInterface.PolygonTrait()
GeoInterface.ncoord(::GeoInterface.PolygonTrait, ::UMMPolygon) = 2
GeoInterface.ngeom(::GeoInterface.PolygonTrait, p::UMMPolygon) = 1 + nexclusive(p)
function GeoInterface.getgeom(::GeoInterface.PolygonTrait, p::UMMPolygon, i)
    i == 1 && return p.Boundary
    return p.ExclusiveZone.Boundaries[i-1]
end

nexclusive(p::UMMPolygon) =
    isnothing(p.ExclusiveZone) ? 0 : length(p.ExclusiveZone.Boundaries)

# `RectangleTrait <: AbstractPolygonTrait`, so a rectangle has one ring and `getgeom` returns
# it closed, matching how GeoInterface implements the trait for `Extents.Extent` itself.
GeoInterface.isgeometry(::Type{<:UMMRectangle}) = true
GeoInterface.geomtrait(::UMMRectangle) = GeoInterface.RectangleTrait()
GeoInterface.ncoord(::GeoInterface.RectangleTrait, ::UMMRectangle) = 2
GeoInterface.ngeom(::GeoInterface.RectangleTrait, ::UMMRectangle) = 1
function GeoInterface.getgeom(::GeoInterface.RectangleTrait, r::UMMRectangle, _)
    w, e = r.WestBoundingCoordinate, r.EastBoundingCoordinate
    s, n = r.SouthBoundingCoordinate, r.NorthBoundingCoordinate
    P = pointtype(r)
    return boundarytype(r)([P(w, s), P(e, s), P(e, n), P(w, n), P(w, s)])
end

# An extent is the rectangle's own definition, so state it directly rather than let
# GeoInterface walk the ring to rediscover it.
GeoInterface.extent(::GeoInterface.RectangleTrait, r::UMMRectangle) = Extent(
    X=(r.WestBoundingCoordinate, r.EastBoundingCoordinate),
    Y=(r.SouthBoundingCoordinate, r.NorthBoundingCoordinate),
)

# Each geometry a record carries is optional, so the collection is however many are present.
GeoInterface.isgeometry(::Type{<:UMMGeometry}) = true
GeoInterface.geomtrait(::UMMGeometry) = GeoInterface.GeometryCollectionTrait()
GeoInterface.ncoord(::GeoInterface.GeometryCollectionTrait, ::UMMGeometry) = 2
GeoInterface.ngeom(::GeoInterface.GeometryCollectionTrait, g::UMMGeometry) =
    sum(count_geometries, geometry_fields(g))
GeoInterface.getgeom(::GeoInterface.GeometryCollectionTrait, g::UMMGeometry, i) =
    nth_geometry(geometry_fields(g), i)

# The four collections a UMM `Geometry` can carry, in the order the geometry interface
# indexes them. Each is optional, so `nothing` stands for an absent one throughout.
geometry_fields(g::UMMGeometry) =
    (g.BoundingRectangles, g.GPolygons, g.Points, g.Lines)

count_geometries(::Nothing) = 0
count_geometries(collection::AbstractVector) = length(collection)

# Index across the collections without concatenating them: the element type of a combined
# vector would be abstract, and `getgeom` is called once per geometry.
function nth_geometry(fields::Tuple, i::Integer)
    remaining = i
    for collection in fields
        n = count_geometries(collection)
        remaining <= n && return collection[remaining]
        remaining -= n
    end
    throw(BoundsError(fields, i))
end

# Which module's structs to build, so a granule's rectangle yields granule points.
pointtype(::Granules.BoundingRectangleType) = Granules.PointType
pointtype(::Collections.BoundingRectangleType) = Collections.PointType
boundarytype(::Granules.BoundingRectangleType) = Granules.BoundaryType
boundarytype(::Collections.BoundingRectangleType) = Collections.BoundaryType

"""
    BoundingRectangleType(extent::Extents.Extent)

A UMM bounding rectangle covering `extent`, which needs `X` and `Y`.

This is how an extent from elsewhere reaches a search: `Extents.extent(raster)` gives `X`/`Y`
that CMR cannot read, and a rectangle is a geometry [`granules`](@ref) accepts.

```jldoctest
extent = EarthData.Extents.Extent(X=(-51.0, -49.0), Y=(40.0, 60.0))
rect = EarthData.Granules.BoundingRectangleType(extent)
rect.WestBoundingCoordinate
# output
-51.0
```
"""
Granules.BoundingRectangleType(extent::Extents.Extent) =
    rectangle_from_extent(Granules.BoundingRectangleType, extent)

Collections.BoundingRectangleType(extent::Extents.Extent) =
    rectangle_from_extent(Collections.BoundingRectangleType, extent)

# The fields are declared (North, West, East, South), so the mapping from an extent lives
# here once: writing it per module is how one of them ends up transposed.
function rectangle_from_extent(::Type{R}, extent::Extents.Extent) where {R<:UMMRectangle}
    (haskey(extent, :X) && haskey(extent, :Y)) || throw(
        ArgumentError(
            "A bounding rectangle needs an extent with X and Y; got $(keys(extent)).",
        ),
    )
    x, y = extent.X, extent.Y
    return R(y[2], x[1], x[2], y[1])
end

"""
    Extents.extent(record::Union{Granules.UMM_G,Collections.UMM_C}) -> Union{Extent,Nothing}

The record's spatial extent in degrees, or `nothing` when it states no coverage.

`X`/`Y` enclose every geometry the record carries — CMR states coverage as bounding
rectangles, polygons, points or lines, and a record may hold more than one kind.

`Extents` is not re-exported, so reach it either with `using Extents` or, as here, through
`EarthData.Extents`.

```jldoctest
g = first(granules(short_name="GEDI02_A"))
ext = EarthData.Extents.extent(g);
haskey(ext, :X) && haskey(ext, :Y)
# output
true
```
"""
function Extents.extent(record::Union{Granules.UMM_G,Collections.UMM_C})
    geometry = @something umm_geometry(record) return nothing
    return Extents.extent(geometry)
end

# Walk the points here rather than call `GeoInterface.extent`, which falls back to
# `Extents.extent` for a type without its own method and would recurse straight back.
Extents.extent(g::Union{UMMLine,UMMBoundary}) =
    points_extent(GeoInterface.getpoint(g))

# The exterior alone, since an `ExclusiveZone` is excluded from the main boundary and so
# cannot extend coverage past it. `getpoint` on a polygon would flatten the holes in too.
Extents.extent(p::UMMPolygon) =
    points_extent(GeoInterface.getpoint(GeoInterface.getexterior(p)))

# A point has no `getpoint`: it is the point, so a zero-width extent at its coordinates.
Extents.extent(p::UMMPoint) = points_extent((p,))

# Walk each field's own vector rather than `geometries`, whose element type is abstract: a
# loop per concrete vector stays inferrable and allocation-free. A record with a `Geometry`
# but nothing in it has no extent at all.
function Extents.extent(geometry::UMMGeometry)
    acc = nothing
    acc = grow_extent(acc, geometry.BoundingRectangles)
    acc = grow_extent(acc, geometry.GPolygons)
    acc = grow_extent(acc, geometry.Points)
    acc = grow_extent(acc, geometry.Lines)
    return acc
end

grow_extent(acc, ::Nothing) = acc
function grow_extent(acc, geometries::AbstractVector)
    for g in geometries
        ext = Extents.extent(g)
        acc = isnothing(acc) ? ext : Extents.union(acc, ext)
    end
    return acc
end

Extents.extent(r::UMMRectangle) = GeoInterface.extent(GeoInterface.geomtrait(r), r)

# Fold rather than `reduce` over a generator: without an `init`, `reduce` cannot infer the
# `Extent` type parameters and every intermediate boxes.
function points_extent(points)
    acc = nothing
    for p in points
        x, y = GeoInterface.x(p), GeoInterface.y(p)
        ext = Extent(X=(x, x), Y=(y, y))
        acc = isnothing(acc) ? ext : Extents.union(acc, ext)
    end
    return acc
end

# The geometry a record carries, or `nothing` if any level of the nesting is absent.
function umm_geometry(record)
    spatial = @something record.SpatialExtent return nothing
    horizontal = @something spatial.HorizontalSpatialDomain return nothing
    return horizontal.Geometry
end
