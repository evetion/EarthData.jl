using Extents
using GeoInterface
using HTTP

const GIW = GeoInterface.Wrappers

# The polygon corners used throughout, wound clockwise. CMR needs counter-clockwise, so the
# expected string below is the reverse of this order.
const cw_corners = [(-51.0, 66.0), (-51.0, 68.0), (-49.0, 68.0), (-49.0, 66.0)]
const ccw_ring = "-49,66,-49,68,-51,68,-51,66,-49,66"

@testset "Geometry conversion" begin
    @testset "bounding box" begin
        @test EarthData.cmr_spatial(:bounding_box, Extent(X=(-51.0, -49.0), Y=(66.0, 68.0))) ==
              "-51,66,-49,68"
        # Extent key order should not matter, and extra dimensions are ignored.
        @test EarthData.cmr_spatial(
            :bounding_box,
            Extent(Y=(66.0, 68.0), Z=(0.0, 1.0), X=(-51.0, -49.0)),
        ) == "-51,66,-49,68"
        @test_throws ArgumentError EarthData.cmr_spatial(:bounding_box, Extent(Z=(0.0, 1.0)))
        @test_throws ArgumentError EarthData.cmr_spatial(:point, Extent(X=(0.0, 1.0), Y=(0.0, 1.0)))
    end

    @testset "point" begin
        @test EarthData.cmr_spatial(:point, GIW.Point(-50.0, 67.0)) == "-50,67"
        @test EarthData.cmr_spatial(:point, (-50.0, 67.0)) == "-50,67"
        @test EarthData.cmr_spatial(:point, [-50.0, 67.0]) == "-50,67"
        # A point alone cannot make a circle, and the error should say why.
        @test_throws ArgumentError EarthData.cmr_spatial(:point, (-50.0, 67.0, 1.0))
        @test_throws ArgumentError EarthData.cmr_spatial(:circle, GIW.Point(-50.0, 67.0))
        @test_throws ArgumentError EarthData.cmr_spatial(:line, GIW.Point(-50.0, 67.0))
    end

    @testset "line" begin
        line = GIW.LineString([(-51.0, 66.0), (-50.0, 67.0), (-49.0, 68.0)])
        @test EarthData.cmr_spatial(:line, line) == "-51,66,-50,67,-49,68"
        @test_throws ArgumentError EarthData.cmr_spatial(:polygon, line)
    end

    @testset "circle" begin
        @test EarthData.cmr_spatial(:circle, (-50.0, 67.0, 10000)) == "-50,67,10000"
        @test EarthData.cmr_spatial(:circle, (GIW.Point(-50.0, 67.0), 10000)) == "-50,67,10000"
        @test_throws ArgumentError EarthData.cmr_spatial(:circle, (-50.0, 67.0))
    end

    @testset "polygon" begin
        # CMR reads a clockwise ring as the complement, i.e. everything except the intended
        # area, so the winding is corrected rather than passed on.
        @test EarthData.cmr_spatial(:polygon, GIW.Polygon([GIW.LinearRing(cw_corners)])) ==
              ccw_ring
        # An already counter-clockwise ring keeps its order.
        @test EarthData.cmr_spatial(
            :polygon,
            GIW.Polygon([GIW.LinearRing(reverse(cw_corners))]),
        ) == ccw_ring
        # An already closed ring is not closed twice.
        @test EarthData.cmr_spatial(
            :polygon,
            GIW.Polygon([GIW.LinearRing([reverse(cw_corners); first(reverse(cw_corners))])]),
        ) == ccw_ring
        # A bare ring works too.
        @test EarthData.cmr_spatial(:polygon, GIW.LinearRing(cw_corners)) == ccw_ring
        # A single-polygon multipolygon is unambiguous; more than one is not.
        @test EarthData.cmr_spatial(
            :polygon,
            GIW.MultiPolygon([GIW.Polygon([GIW.LinearRing(cw_corners)])]),
        ) == ccw_ring
        poly = GIW.Polygon([GIW.LinearRing(cw_corners)])
        @test_throws ArgumentError EarthData.cmr_spatial(
            :polygon,
            GIW.MultiPolygon([poly, poly]),
        )
        # CMR's polygon is a single ring, so a hole cannot be expressed.
        hole = GIW.LinearRing([(-50.6, 66.4), (-50.4, 66.4), (-50.4, 66.6)])
        @test_throws ArgumentError EarthData.cmr_spatial(
            :polygon,
            GIW.Polygon([GIW.LinearRing(cw_corners), hole]),
        )
        @test_throws ArgumentError EarthData.cmr_spatial(
            :polygon,
            GIW.LinearRing([(0.0, 0.0), (1.0, 1.0)]),
        )
        @test_throws ArgumentError EarthData.cmr_spatial(:bounding_box, poly)
    end

    @testset "pass-through and rejection" begin
        # Strings are untouched, so calls written before geometries were accepted behave the
        # same. Note this string is clockwise and stays that way.
        @test EarthData.cmr_spatial(:polygon, "-51,66,-51,68,-49,68,-51,66") ==
              "-51,66,-51,68,-49,68,-51,66"
        @test EarthData.cmr_spatial(:point, nothing) === nothing
        @test_throws ArgumentError EarthData.cmr_spatial(:point, Dict("x" => 1))
        # Small coordinates must not come out in exponent notation, which CMR rejects.
        @test EarthData.cmr_spatial(:point, (1.0e-5, 0.0)) == "0.00001,0"
    end

    @testset "vector of geometries" begin
        # CMR reads a repeated spatial parameter as the union of its values.
        points = [GIW.Point(-50.0, 67.0), GIW.Point(-40.0, 60.0)]
        @test EarthData.cmr_spatial(:point, points) == ["-50,67", "-40,60"]
        @test_throws ArgumentError EarthData.cmr_spatial(
            :point,
            GIW.MultiPoint([(-50.0, 67.0), (-40.0, 60.0)]),
        )
    end
end

@testset "Geometry in a granule search" begin
    requests = []
    responses = [HTTP.Response(200, [], cmr_response(["G1"], "granule"))]

    EarthData.granules(;
        short_name="TEST",
        bounding_box=Extent(X=(-51.0, -49.0), Y=(66.0, 68.0)),
        requester=recording_requester(responses, requests),
    )

    @test occursin("bounding_box=$(HTTP.URIs.escapeuri("-51,66,-49,68"))", requests[1].body)

    # A repeated parameter must survive form encoding as two entries, not one joined value.
    requests = []
    responses = [HTTP.Response(200, [], cmr_response(["G1"], "granule"))]
    EarthData.granules(;
        short_name="TEST",
        point=[GIW.Point(-50.0, 67.0), GIW.Point(-40.0, 60.0)],
        requester=recording_requester(responses, requests),
    )
    @test occursin("point=$(HTTP.URIs.escapeuri("-50,67"))", requests[1].body)
    @test occursin("point=$(HTTP.URIs.escapeuri("-40,60"))", requests[1].body)
end
