using Dates
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

    # A range of dates is an `AbstractVector`, so it would become one clause per element —
    # 121 of them here. Ask for the endpoints rather than send a union nobody asked for.
    @test_throws "does not take a range" EarthData.cmr_temporal(
        :temporal,
        Date(2019, 1, 1):Day(1):Date(2019, 5, 1),
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
    # `updated_since` is excluded: CMR takes a single instant there and rejects a range.
    for key in EarthData.range_date_params
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

    # `updated_since` means "revised after", so CMR takes one instant and answers a pair
    # with "updated_since datetime is invalid". Sending the range is a wasted round-trip.
    for key in EarthData.instant_date_params
        requests = []
        responses = [HTTP.Response(200, [], cmr_response(["G1"], "granule"))]
        EarthData.granules(;
            key => Date(2019, 4, 18),
            requester=recording_requester(responses, requests),
        )
        @test occursin(
            "$(key)=$(HTTP.URIs.escapeuri("2019-04-18T00:00:00Z"))",
            requests[1].body,
        )
        @test_throws "takes a single date, not a range" EarthData.cmr_temporal(
            key,
            (Date(2019, 4, 18), Date(2019, 4, 20)),
        )
    end
end
