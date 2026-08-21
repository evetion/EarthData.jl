using Dates
using Extents
using HTTP
using Test

@testset "Temporal conversion" begin
    # A `Date` is midnight UTC; a `DateTime` keeps its time. Both need the trailing Z, and
    # neither may come out in Julia's default `2019-04-18T00:00:00` form without it.
    @test EarthData.cmr_temporal(:temporal, Date(2019, 4, 18)) == "2019-04-18T00:00:00Z"
    @test EarthData.cmr_temporal(:temporal, DateTime(2019, 4, 18, 6, 30)) ==
          "2019-04-18T06:30:00Z"

    # Ranges, including the open-ended forms CMR reads as an empty field.
    @test EarthData.cmr_temporal(:temporal, (Date(2019, 4, 18), Date(2019, 4, 20))) ==
          "2019-04-18T00:00:00Z,2019-04-20T00:00:00Z"
    @test EarthData.cmr_temporal(:temporal, (Date(2019, 4, 18), nothing)) ==
          "2019-04-18T00:00:00Z,"
    @test EarthData.cmr_temporal(:temporal, (nothing, Date(2019, 4, 20))) ==
          ",2019-04-20T00:00:00Z"

    # Strings pass through, so existing calls are unaffected.
    @test EarthData.cmr_temporal(:temporal, "2019-04-18T00:00:00Z,") ==
          "2019-04-18T00:00:00Z,"
    @test EarthData.cmr_temporal(:temporal, nothing) === nothing

    # A vector is a repeated parameter, which CMR reads as the union.
    @test EarthData.cmr_temporal(:temporal, [Date(2019, 1, 1), Date(2020, 1, 1)]) ==
          ["2019-01-01T00:00:00Z", "2020-01-01T00:00:00Z"]

    # A range is an `AbstractVector`, but it means the span it covers: without its own
    # method this would become one clause per element — 121 of them here.
    @test EarthData.cmr_temporal(:temporal, Date(2019, 1, 1):Day(1):Date(2019, 5, 1)) ==
          "2019-01-01T00:00:00Z,2019-05-01T00:00:00Z"

    # An `Extent`'s `Ti`, so `Extents.extent(raster)` can constrain a search directly, the
    # way `bounding_box` already takes its `X`/`Y`.
    @test EarthData.cmr_temporal(
        :temporal,
        Extent(Ti=(Date(2019, 4, 18), Date(2019, 4, 20))),
    ) == "2019-04-18T00:00:00Z,2019-04-20T00:00:00Z"
    @test_throws ArgumentError EarthData.cmr_temporal(
        :temporal,
        Extent(X=(-51.0, -49.0)),
    )

    # A backwards range would silently return nothing from CMR rather than erroring.
    @test_throws ArgumentError EarthData.cmr_temporal(
        :temporal,
        (Date(2019, 4, 20), Date(2019, 4, 18)),
    )
    @test_throws ArgumentError EarthData.cmr_temporal(:temporal, (nothing, nothing))
    @test_throws ArgumentError EarthData.cmr_temporal(:temporal, 2019)
end

@testset "Temporal parameters in a search" begin
    # Every date-valued CMR parameter goes through the conversion, not just `temporal`.
    for key in EarthData.temporal_params
        # Two of the eight are collection-only (`has_granules_*_at`) and two granule-only
        # (`production_date`, `equator_crossing_date`), so each has to go to the endpoint
        # that accepts it — with a matching response body to parse.
        search, id, kind =
            key in fieldnames(EarthData.GranuleRequest) ?
            (EarthData.granules, "G1", "granule") :
            (EarthData.collections, "C1", "collection")
        requests = []
        responses = [HTTP.Response(200, [], cmr_response([id], kind))]
        search(;
            key => (Date(2019, 4, 18), Date(2019, 4, 20)),
            requester=recording_requester(responses, requests),
        )
        @test occursin(
            "$(key)=$(HTTP.URIs.escapeuri("2019-04-18T00:00:00Z,2019-04-20T00:00:00Z"))",
            requests[1].body,
        )
    end
end
