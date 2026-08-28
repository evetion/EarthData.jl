using Extents
using JSON3
using Test
import GeoInterface as GI

# A minimal granule carrying `geometry` as its horizontal spatial domain, parsed the way a
# real response is so the structs are built by the same path the package uses.
function extent_granule(geometry)
    umm = Dict{String,Any}(
        "GranuleUR" => "G1",
        "CollectionReference" => Dict("ShortName" => "TEST", "Version" => "001"),
        "MetadataSpecification" =>
            Dict("URL" => "https://example.test", "Version" => "1.6.6", "Name" => "UMM-G"),
        "ProviderDates" => [Dict("Type" => "Insert", "Date" => "2020-01-01T00:00:00Z")],
        "SpatialExtent" => Dict("HorizontalSpatialDomain" => Dict("Geometry" => geometry)),
    )
    return JSON3.read(JSON3.write(umm), EarthData.Granules.UMM_G)
end

point(lon, lat) = Dict("Longitude" => lon, "Latitude" => lat)

rectangle(west, east, south, north) = Dict(
    "WestBoundingCoordinate" => west,
    "EastBoundingCoordinate" => east,
    "SouthBoundingCoordinate" => south,
    "NorthBoundingCoordinate" => north,
)

const G = EarthData.Granules

@testset "Record equality" begin
    # A record is its fields, so two parsed from the same JSON describe the same thing. The
    # default compares a struct holding a `Vector` by that vector's identity, which would make
    # rings with identical coordinates differ.
    points() = [G.PointType(-10.0, 0.0), G.PointType(5.0, 0.0), G.PointType(5.0, 10.0)]
    @test G.PointType(1.0, 2.0) == G.PointType(1.0, 2.0)
    @test G.BoundaryType(points()) == G.BoundaryType(points())
    # Winding matters to CMR, so a reversed ring is a different boundary.
    @test G.BoundaryType(points()) != G.BoundaryType(reverse(points()))
    @test G.GPolygonType(nothing, G.BoundaryType(points())) ==
          G.GPolygonType(nothing, G.BoundaryType(points()))

    # `hash` has to agree with `==`, or equal records collide as `Dict` keys and `Set` keeps
    # duplicates.
    a, b = G.BoundaryType(points()), G.BoundaryType(points())
    @test hash(a) == hash(b)
    @test length(Set([a, b])) == 1
    @test Dict(a => 1)[b] == 1
    @test isequal(a, b)

    # Different types with the same field values are still different records.
    @test G.PointType(1.0, 2.0) != G.BoundingRectangleType(1.0, 2.0, 3.0, 4.0)
end

@testset "GeoInterface conformance" begin
    # GeoInterface's own conformance check, which exercises isgeometry, geomtrait, ncoord,
    # ngeom, getgeom and getcoord — including the two-argument forms a consumer calls — and
    # walks into each subgeometry.
    ring = G.BoundaryType([
        G.PointType(-10.0, 0.0),
        G.PointType(5.0, 0.0),
        G.PointType(5.0, 10.0),
        G.PointType(-10.0, 0.0),
    ])
    rect = G.BoundingRectangleType(60.0, -51.0, -49.0, 40.0)
    @test GI.testgeometry(G.PointType(3.0, 4.0))
    @test GI.testgeometry(G.LineType([G.PointType(0.0, 0.0), G.PointType(2.0, -3.0)]))
    @test GI.testgeometry(ring)
    @test GI.testgeometry(G.GPolygonType(nothing, ring))
    @test GI.testgeometry(rect)
    @test GI.testgeometry(G.GeometryType([rect], nothing, [G.PointType(30.0, 40.0)], nothing))

    # Collections generates field-identical structs, so the same union serves both.
    C = EarthData.Collections
    @test GI.testgeometry(C.PointType(3.0, 4.0))
    @test GI.testgeometry(C.BoundingRectangleType(60.0, -51.0, -49.0, 40.0))

    # A rectangle is a polygon with one closed ring, and its corners are that ring's points.
    @test GI.ngeom(rect) == 1
    @test GI.nring(rect) == 1
    @test GI.trait(GI.getgeom(rect, 1)) isa GI.LinearRingTrait
    @test length(collect(GI.getpoint(rect))) == 5
    @test GI.ncoord(rect) == 2

    # A collection indexes across the four fields in order, so an index has to carry past the
    # collections before the one holding it rather than restart at each.
    mixed = G.GeometryType(
        [rect, G.BoundingRectangleType(1.0, 2.0, 3.0, 4.0)],
        [G.GPolygonType(nothing, ring)],
        [G.PointType(30.0, 40.0)],
        [G.LineType([G.PointType(0.0, 0.0), G.PointType(2.0, -3.0)])],
    )
    @test GI.ngeom(mixed) == 5
    @test GI.getgeom(mixed, 2) == G.BoundingRectangleType(1.0, 2.0, 3.0, 4.0)
    @test GI.trait(GI.getgeom(mixed, 3)) isa GI.PolygonTrait
    @test GI.trait(GI.getgeom(mixed, 4)) isa GI.PointTrait
    @test GI.trait(GI.getgeom(mixed, 5)) isa GI.LineStringTrait
    @test_throws BoundsError GI.getgeom(mixed, 6)

    # An absent collection contributes nothing, so indexing skips straight past it.
    @test GI.trait(GI.getgeom(G.GeometryType(nothing, nothing, [G.PointType(1.0, 2.0)], nothing), 1)) isa
          GI.PointTrait
end

@testset "UMM geometry traits" begin
    # Every UMM geometry is a geometry, so anything taking GeoInterface accepts one.
    rect = G.BoundingRectangleType(60.0, -51.0, -49.0, 40.0)
    @test GI.isgeometry(rect)
    @test GI.trait(rect) isa GI.RectangleTrait

    pt = G.PointType(3.0, 4.0)
    @test GI.trait(pt) isa GI.PointTrait
    @test GI.x(pt) == 3.0
    @test GI.y(pt) == 4.0

    line = G.LineType([G.PointType(0.0, 0.0), G.PointType(2.0, -3.0)])
    @test GI.trait(line) isa GI.LineStringTrait
    @test GI.npoint(line) == 2

    # A boundary is closed and counter-clockwise by UMM's own definition, so a linear ring.
    ring = G.BoundaryType([
        G.PointType(-10.0, 0.0),
        G.PointType(5.0, 0.0),
        G.PointType(5.0, 10.0),
        G.PointType(-10.0, 0.0),
    ])
    @test GI.trait(ring) isa GI.LinearRingTrait

    # An ExclusiveZone is excluded from the main boundary, which is what a hole is.
    poly = G.GPolygonType(nothing, ring)
    @test GI.trait(poly) isa GI.PolygonTrait
    @test GI.nhole(poly) == 0

    hole = G.BoundaryType([
        G.PointType(-1.0, 1.0),
        G.PointType(1.0, 1.0),
        G.PointType(1.0, 2.0),
        G.PointType(-1.0, 1.0),
    ])
    holed = G.GPolygonType(G.ExclusiveZoneType([hole]), ring)
    @test GI.nhole(holed) == 1
    @test GI.getexterior(holed) === ring
    @test first(GI.gethole(holed)) === hole

    # A record may carry several kinds of geometry at once, so it is a collection.
    geometry = G.GeometryType([rect], [poly], [pt], [line])
    @test GI.trait(geometry) isa GI.GeometryCollectionTrait
    @test GI.ngeom(geometry) == 4
end

@testset "Geometry extents" begin
    # West/east are X and south/north are Y; mixing that pairing up is the classic way to
    # transpose an extent, and it would still parse.
    ext = Extents.extent(
        extent_granule(Dict("BoundingRectangles" => [rectangle(-51.0, -49.0, 40.0, 60.0)])),
    )
    @test ext == Extent(X=(-51.0, -49.0), Y=(40.0, 60.0))

    # A polygon is bounded by its outer boundary. An `ExclusiveZone` is a hole *inside* it,
    # so it cannot widen the extent.
    polygon = Dict(
        "Boundary" => Dict(
            "Points" =>
                [point(-10.0, 0.0), point(5.0, 0.0), point(5.0, 10.0), point(-10.0, 0.0)],
        ),
    )
    @test Extents.extent(extent_granule(Dict("GPolygons" => [polygon]))) ==
          Extent(X=(-10.0, 5.0), Y=(0.0, 10.0))

    # UMM excludes an `ExclusiveZone` from the main boundary, so the exterior alone bounds
    # the coverage even where a zone is recorded outside it — walking every ring's points
    # would report an area the granule does not cover.
    outside = Dict(
        "Boundary" => Dict(
            "Points" =>
                [point(-10.0, 0.0), point(5.0, 0.0), point(5.0, 10.0), point(-10.0, 0.0)],
        ),
        "ExclusiveZone" => Dict(
            "Boundaries" => [
                Dict(
                    "Points" => [
                        point(20.0, 20.0),
                        point(21.0, 20.0),
                        point(21.0, 21.0),
                        point(20.0, 20.0),
                    ],
                ),
            ],
        ),
    )
    @test Extents.extent(extent_granule(Dict("GPolygons" => [outside]))) ==
          Extent(X=(-10.0, 5.0), Y=(0.0, 10.0))

    # Points and lines are the other two forms CMR uses. A point is a zero-width extent.
    @test Extents.extent(extent_granule(Dict("Points" => [point(3.0, 4.0)]))) ==
          Extent(X=(3.0, 3.0), Y=(4.0, 4.0))

    line = Dict("Points" => [point(0.0, 0.0), point(2.0, -3.0)])
    @test Extents.extent(extent_granule(Dict("Lines" => [line]))) ==
          Extent(X=(0.0, 2.0), Y=(-3.0, 0.0))

    # A record may carry several geometries, of more than one kind, and the result has to
    # enclose all of them rather than the first collection found.
    @test Extents.extent(
        extent_granule(
            Dict(
                "BoundingRectangles" => [rectangle(-20.0, -15.0, -1.0, 1.0)],
                "Points" => [point(30.0, 40.0)],
            ),
        ),
    ) == Extent(X=(-20.0, 30.0), Y=(-1.0, 40.0))

    # No coverage at all reports nothing rather than a zero-width extent at the origin.
    @test Extents.extent(extent_granule(Dict{String,Any}())) === nothing
end

@testset "GeoInterface.convert" begin
    C = EarthData.Collections
    ring = G.BoundaryType([
        G.PointType(-10.0, 0.0),
        G.PointType(5.0, 0.0),
        G.PointType(5.0, 10.0),
        G.PointType(-10.0, 0.0),
    ])

    # Dispatching on the trait means any GeoInterface rectangle converts, not just an
    # `Extent` — the reason this is `GeoInterface.convert` and not a constructor per source
    # type.
    rect = GI.convert(G.BoundingRectangleType, Extent(X=(-51.0, -49.0), Y=(66.0, 68.0)))
    @test rect.WestBoundingCoordinate == -51.0
    @test rect.SouthBoundingCoordinate == 66.0
    @test rect.EastBoundingCoordinate == -49.0
    @test rect.NorthBoundingCoordinate == 68.0

    @test GI.convert(G.PointType, G.PointType(3.0, 4.0)) == G.PointType(3.0, 4.0)
    @test GI.convert(G.BoundaryType, ring) == ring
    @test GI.convert(G.LineType, G.LineType([G.PointType(0.0, 0.0), G.PointType(2.0, -3.0)])) ==
          G.LineType([G.PointType(0.0, 0.0), G.PointType(2.0, -3.0)])

    # An `ExclusiveZone` is the polygon's holes, so converting has to carry them across or it
    # would silently widen the area to the exterior.
    hole = G.BoundaryType([
        G.PointType(-1.0, 1.0),
        G.PointType(1.0, 1.0),
        G.PointType(1.0, 2.0),
        G.PointType(-1.0, 1.0),
    ])
    holed = G.GPolygonType(G.ExclusiveZoneType([hole]), ring)
    @test GI.convert(G.GPolygonType, holed) == holed
    @test GI.nhole(GI.convert(G.GPolygonType, holed)) == 1
    # A polygon with no holes gets no zone rather than an empty one.
    @test isnothing(GI.convert(G.GPolygonType, G.GPolygonType(nothing, ring)).ExclusiveZone)

    # `Granules` and `Collections` generate field-identical structs, so a geometry from one
    # converts into the other — which is what a collection search needs from a granule result.
    @test GI.convert(C.GPolygonType, holed) isa C.GPolygonType
    @test GI.nhole(GI.convert(C.GPolygonType, holed)) == 1
    @test GI.convert(C.PointType, G.PointType(3.0, 4.0)) == C.PointType(3.0, 4.0)
end

@testset "GeoInterface.geometry" begin
    # The accessor reaches through SpatialExtent.HorizontalSpatialDomain.Geometry, so a
    # caller does not have to know the nesting.
    granule = extent_granule(
        Dict("BoundingRectangles" => [rectangle(-51.0, -49.0, 40.0, 60.0)]),
    )
    @test GI.trait(GI.geometry(granule)) isa GI.GeometryCollectionTrait
    @test GI.ngeom(GI.geometry(granule)) == 1

    # A record stating no coverage has no geometry, rather than an empty one.
    bare = JSON3.read(
        JSON3.write(
            Dict{String,Any}(
                "GranuleUR" => "G1",
                "CollectionReference" => Dict("ShortName" => "T", "Version" => "1"),
                "MetadataSpecification" => Dict(
                    "URL" => "https://example.test",
                    "Version" => "1.6.6",
                    "Name" => "UMM-G",
                ),
                "ProviderDates" =>
                    [Dict("Type" => "Insert", "Date" => "2020-01-01T00:00:00Z")],
            ),
        ),
        EarthData.Granules.UMM_G,
    )
    @test isnothing(GI.geometry(bare))
    @test isnothing(Extents.extent(bare))
end

@testset "Extent to bounding rectangle" begin
    # How an extent from elsewhere reaches a search: `Extents.extent(raster)` gives X/Y that
    # CMR cannot read, and a rectangle is a geometry `granules` accepts.
    rect = G.BoundingRectangleType(Extent(X=(-51.0, -49.0), Y=(40.0, 60.0)))
    @test rect.WestBoundingCoordinate == -51.0
    @test rect.EastBoundingCoordinate == -49.0
    @test rect.SouthBoundingCoordinate == 40.0
    @test rect.NorthBoundingCoordinate == 60.0

    # Round-tripping is what catches a transposed field order, since the fields are declared
    # (North, West, East, South).
    @test Extents.extent(rect) == Extent(X=(-51.0, -49.0), Y=(40.0, 60.0))

    # Extra keys are fine, but X and Y are required.
    @test Extents.extent(
        G.BoundingRectangleType(Extent(X=(0.0, 1.0), Y=(2.0, 3.0), Z=(4.0, 5.0))),
    ) == Extent(X=(0.0, 1.0), Y=(2.0, 3.0))
    @test_throws ArgumentError G.BoundingRectangleType(Extent(X=(0.0, 1.0)))
end

@testset "UMM geometries as search parameters" begin
    # Implementing the traits makes the UMM types valid search inputs, since `cmr_spatial`
    # already dispatches on them: a granule's coverage can constrain the next search.
    rect = G.BoundingRectangleType(60.0, -51.0, -49.0, 40.0)
    @test EarthData.cmr_spatial(:bounding_box, rect) == "-51,40,-49,60"
    @test EarthData.cmr_spatial(:point, G.PointType(3.0, 4.0)) == "3,4"
    @test EarthData.cmr_spatial(
        :line,
        G.LineType([G.PointType(0.0, 0.0), G.PointType(2.0, -3.0)]),
    ) == "0,0,2,-3"

    ring = G.BoundaryType([
        G.PointType(-10.0, 0.0),
        G.PointType(5.0, 0.0),
        G.PointType(5.0, 10.0),
        G.PointType(-10.0, 0.0),
    ])
    # CMR's `polygon` wants a closed counter-clockwise ring, which is what UMM stores.
    @test EarthData.cmr_spatial(:polygon, G.GPolygonType(nothing, ring)) ==
          "-10,0,5,0,5,10,-10,0"

    # CMR cannot express a hole, so a polygon with an ExclusiveZone has to be refused rather
    # than silently searched as its outer ring.
    hole = G.BoundaryType([
        G.PointType(-1.0, 1.0),
        G.PointType(1.0, 1.0),
        G.PointType(1.0, 2.0),
        G.PointType(-1.0, 1.0),
    ])
    @test_throws ArgumentError EarthData.cmr_spatial(
        :polygon,
        G.GPolygonType(G.ExclusiveZoneType([hole]), ring),
    )
end

@testset "Records as features" begin
    # A record pairs coverage with the rest of what CMR knows, which is what a feature is.
    granule = extent_granule(
        Dict("BoundingRectangles" => [rectangle(-51.0, -49.0, 40.0, 60.0)]),
    )
    @test GI.isfeature(granule)
    @test GI.trait(granule) isa GI.FeatureTrait
    # A feature is not itself a geometry, so `geomtrait` stays `nothing` while `geometry`
    # returns the collection the record carries.
    @test isnothing(GI.geomtrait(granule))
    @test GI.trait(GI.geometry(granule)) isa GI.GeometryCollectionTrait
    @test GI.testfeature(granule)

    # `SpatialExtent` is the geometry, so it is not repeated in the properties.
    props = GI.properties(granule)
    @test :SpatialExtent ∉ keys(props)
    @test props.GranuleUR == "G1"
    @test length(keys(props)) == length(fieldnames(typeof(granule))) - 1

    # A record with no coverage is still a feature, just one with no geometry.
    bare = JSON3.read(
        JSON3.write(
            Dict{String,Any}(
                "GranuleUR" => "G2",
                "CollectionReference" => Dict("ShortName" => "T", "Version" => "1"),
                "MetadataSpecification" => Dict(
                    "URL" => "https://example.test",
                    "Version" => "1.6.6",
                    "Name" => "UMM-G",
                ),
                "ProviderDates" =>
                    [Dict("Type" => "Insert", "Date" => "2020-01-01T00:00:00Z")],
            ),
        ),
        EarthData.Granules.UMM_G,
    )
    @test GI.testfeature(bare)
    @test isnothing(GI.geometry(bare))
end

@testset "Results as a feature collection" begin
    # A search returns a plain `Vector`, so the collection is keyed on the element type.
    records = [
        extent_granule(Dict("BoundingRectangles" => [rectangle(-51.0, -49.0, 40.0, 60.0)])),
        extent_granule(Dict("Points" => [point(30.0, 40.0)])),
    ]
    @test GI.isfeaturecollection(records)
    @test GI.trait(records) isa GI.FeatureCollectionTrait
    @test GI.nfeature(records) == 2
    @test GI.trait(GI.getfeature(records, 1)) isa GI.FeatureTrait
    @test GI.testfeaturecollection(records)

    # The collection's extent encloses every record that states one.
    @test GI.extent(records) == Extent(X=(-51.0, 30.0), Y=(40.0, 60.0))

    # An empty result has no extent rather than a zero-width one at the origin.
    @test isnothing(Extents.extent(EarthData.Granules.UMM_G[]))
    @test GI.nfeature(EarthData.Granules.UMM_G[]) == 0
end
