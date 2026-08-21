using Dates
using Extents
using JSON3
using Test

# A minimal granule carrying `geometry` as its horizontal spatial domain and `temporal` as
# its temporal extent, parsed the way a real response is so the structs are built by the
# same path the package uses.
function extent_granule(geometry; temporal=nothing)
    umm = Dict{String,Any}(
        "GranuleUR" => "G1",
        "CollectionReference" => Dict("ShortName" => "TEST", "Version" => "001"),
        "MetadataSpecification" =>
            Dict("URL" => "https://example.test", "Version" => "1.6.6", "Name" => "UMM-G"),
        "ProviderDates" => [Dict("Type" => "Insert", "Date" => "2020-01-01T00:00:00Z")],
        "SpatialExtent" => Dict("HorizontalSpatialDomain" => Dict("Geometry" => geometry)),
    )
    isnothing(temporal) || (umm["TemporalExtent"] = temporal)
    return JSON3.read(JSON3.write(umm), EarthData.Granules.UMM_G)
end

point(lon, lat) = Dict("Longitude" => lon, "Latitude" => lat)

rectangle(west, east, south, north) = Dict(
    "WestBoundingCoordinate" => west,
    "EastBoundingCoordinate" => east,
    "SouthBoundingCoordinate" => south,
    "NorthBoundingCoordinate" => north,
)

@testset "Granule extent" begin
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

@testset "Granule extent time" begin
    geometry = Dict("BoundingRectangles" => [rectangle(-51.0, -49.0, 40.0, 60.0)])

    # CMR writes times with a `Z` and often milliseconds, neither of which `DateTime`'s
    # parser accepts, so both have to be trimmed rather than passed through.
    ext = Extents.extent(
        extent_granule(
            geometry;
            temporal=Dict(
                "RangeDateTime" => Dict(
                    "BeginningDateTime" => "2019-04-04T18:05:55Z",
                    "EndingDateTime" => "2019-04-04T19:38:36.000Z",
                ),
            ),
        ),
    )
    @test ext.Ti == (DateTime(2019, 4, 4, 18, 5, 55), DateTime(2019, 4, 4, 19, 38, 36))
    # The spatial keys survive alongside Ti.
    @test ext.X == (-51.0, -49.0)

    # A single instant is a zero-width interval, so it still composes with a range search.
    ext = Extents.extent(
        extent_granule(
            geometry;
            temporal=Dict("SingleDateTime" => "2019-04-04T18:05:55.000Z"),
        ),
    )
    @test ext.Ti == (DateTime(2019, 4, 4, 18, 5, 55), DateTime(2019, 4, 4, 18, 5, 55))

    # An open-ended range is bounded by whichever end it does state.
    ext = Extents.extent(
        extent_granule(
            geometry;
            temporal=Dict(
                "RangeDateTime" =>
                    Dict("BeginningDateTime" => "2019-04-04T18:05:55Z"),
            ),
        ),
    )
    @test ext.Ti == (DateTime(2019, 4, 4, 18, 5, 55), DateTime(2019, 4, 4, 18, 5, 55))

    # Without a temporal extent there is no Ti at all, so callers must use `haskey`.
    @test !haskey(Extents.extent(extent_granule(geometry)), :Ti)
end
