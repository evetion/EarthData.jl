using Dates
using HTTP
using Test

# The wire form of one parameter: a request stores the `Date` it was given, and the ISO 8601
# spelling appears only on the way out.
stored(key, value) = getfield(EarthData.GranuleRequest(; key => value), key)
wire(key, value) = only(EarthData.cmr_pairs(key, stored(key, value)))

@testset "Temporal conversion" begin
    # A `Date` is midnight UTC; a `DateTime` keeps its time. Both need the trailing Z, and
    # neither may come out in Julia's default `2019-04-18T00:00:00` form without it.
    @test wire(:temporal, Date(2019, 4, 18)) == ("temporal" => "2019-04-18T00:00:00Z")
    @test wire(:temporal, DateTime(2019, 4, 18, 6, 30)) ==
          ("temporal" => "2019-04-18T06:30:00Z")

    # Ranges, including the open-ended forms CMR reads as an empty field.
    @test wire(:temporal, (Date(2019, 4, 18), Date(2019, 4, 20))) ==
          ("temporal" => "2019-04-18T00:00:00Z,2019-04-20T00:00:00Z")
    @test wire(:temporal, (Date(2019, 4, 18), nothing)) ==
          ("temporal" => "2019-04-18T00:00:00Z,")
    @test wire(:temporal, (nothing, Date(2019, 4, 20))) ==
          ("temporal" => ",2019-04-20T00:00:00Z")

    # Strings pass through, so a hand-written constraint still works.
    @test wire(:temporal, "2019-04-18T00:00:00Z,") ==
          ("temporal" => "2019-04-18T00:00:00Z,")
    @test EarthData.GranuleRequest(temporal=nothing).temporal === nothing

    # A vector is a repeated parameter, which CMR reads as the union.
    @test EarthData.cmr_pairs(
        :temporal,
        stored(:temporal, [Date(2019, 1, 1), Date(2020, 1, 1)]),
    ) == ["temporal" => "2019-01-01T00:00:00Z", "temporal" => "2020-01-01T00:00:00Z"]

    # A `StepRange` of dates is an `AbstractVector`, so it would become one clause per
    # element — 121 of them here. Ask for the endpoints rather than send a union nobody
    # asked for.
    @test_throws "does not take a range of dates" EarthData.GranuleRequest(
        temporal=Date(2019, 1, 1):Day(1):Date(2019, 5, 1),
    )

    # A backwards range would silently return nothing from CMR rather than erroring.
    @test_throws "ends before it starts" EarthData.GranuleRequest(
        temporal=(Date(2019, 4, 20), Date(2019, 4, 18)),
    )
    @test_throws "needs at least one bound" EarthData.GranuleRequest(
        temporal=(nothing, nothing),
    )
    @test_throws ArgumentError EarthData.GranuleRequest(temporal=2019)

    # The error names the field and quotes its docstring, so the message says which keyword
    # was wrong and what it means.
    @test_throws "`temporal`" EarthData.GranuleRequest(temporal=2019)
    @test_throws "When the granule was observed" EarthData.GranuleRequest(temporal=2019)
end

@testset "Temporal parameters in a search" begin
    # Every date-valued CMR parameter goes through the conversion, not just `temporal`.
    # `updated_since` is excluded: CMR takes a single instant there and rejects a range.
    # Each endpoint has range parameters the other does not — `has_granules_*_at` is
    # collection-only, `production_date` and `equator_crossing_date` granule-only — so each
    # is swept against the search that accepts it, with a matching response body to parse.
    for (R, search, id, kind) in (
        (EarthData.GranuleRequest, EarthData.granules, "G1", "granule"),
        (EarthData.CollectionRequest, EarthData.collections, "C1", "collection"),
    ), key in param_names(R, EarthData.DateRangeParam)
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
    for key in param_names(EarthData.GranuleRequest, EarthData.DateParam)
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
        # A range here is a `MethodError` from the field type — `DateParam` has no tuple
        # member — rather than a check inside the conversion.
        @test_throws ArgumentError EarthData.granules(;
            key => (Date(2019, 4, 18), Date(2019, 4, 20)),
            requester=recording_requester([], []),
        )
        @test_throws "takes Date, DateTime or String" EarthData.granules(;
            key => (Date(2019, 4, 18), Date(2019, 4, 20)),
            requester=recording_requester([], []),
        )
    end
end
