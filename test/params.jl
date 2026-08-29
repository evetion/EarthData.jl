using HTTP
using Test

# Every rejection below is a CMR HTTP 400 without the conversion, except where noted. The
# wording in each `@test_throws` is what the user has to act on.

@testset "Boolean parameters" begin
    @test EarthData.cmr_bool(:downloadable, true) == "true"
    @test EarthData.cmr_bool(:downloadable, false) == "false"
    @test isnothing(EarthData.cmr_bool(:downloadable, nothing))

    # A string is the escape hatch, as in every other family. CMR accepts spellings this
    # module does not build — `TRUE` and `True` among them — so the string is passed on and
    # CMR judges it, rather than being checked against a list stricter than the service.
    @test EarthData.cmr_bool(:downloadable, "true") == "true"
    @test EarthData.cmr_bool(:downloadable, "TRUE") == "TRUE"
    @test EarthData.cmr_bool(:downloadable, "unset") == "unset"

    # `1` is not a synonym for `true` here — CMR rejects it outright.
    @test_throws "takes `true` or `false`" EarthData.cmr_bool(:downloadable, 1)
    @test_throws "takes `true` or `false`" EarthData.cmr_bool(:downloadable, 42)

    # Naming the parameter matters: the message is the only clue which keyword was wrong.
    @test_throws "cloud_hosted" EarthData.cmr_bool(:cloud_hosted, 0)
end

@testset "Numeric range parameters" begin
    # CMR answers a single value with "The min and max values of a numeric range cannot both
    # be nil", which does not say what to do about it.
    @test_throws "takes a (min, max) range" EarthData.cmr_numeric_range(:cloud_cover, 5)

    @test EarthData.cmr_numeric_range(:cloud_cover, (0.2, nothing)) == "0.2,"
    @test EarthData.cmr_numeric_range(:cloud_cover, (nothing, 30)) == ",30"
    @test EarthData.cmr_numeric_range(:cloud_cover, (0.5, 20.5)) == "0.5,20.5"
    @test EarthData.cmr_numeric_range(:equator_crossing_longitude, (-10, 10)) == "-10,10"

    # A range with no bounds is not a search, and a backwards one silently matches nothing.
    @test_throws "needs at least one bound" EarthData.cmr_numeric_range(
        :cloud_cover,
        (nothing, nothing),
    )
    @test_throws "ends below where it starts" EarthData.cmr_numeric_range(
        :cloud_cover,
        (30, 10),
    )

    # `string(1e-5)` is "1.0e-5", which CMR rejects; `coord_string` writes plain decimals.
    @test EarthData.cmr_numeric_range(:cloud_cover, (1e-5, nothing)) == "0.00001,"

    @test EarthData.cmr_numeric_range(:cloud_cover, "0.2,30") == "0.2,30"
    @test_throws "takes a (min, max) tuple" EarthData.cmr_numeric_range(
        :cloud_cover,
        Dict(),
    )
end

@testset "Positive integer parameters" begin
    @test EarthData.cmr_positive_int(:cycle, 1) == "1"
    @test EarthData.cmr_positive_int(:cycle, "1") == "1"

    # CMR: "Cycle must be a positive integer, but was [1.5]".
    @test_throws "must be a positive integer" EarthData.cmr_positive_int(:cycle, 1.5)
    @test_throws "must be a positive integer" EarthData.cmr_positive_int(:cycle, -1)
    @test_throws "must be a positive integer" EarthData.cmr_positive_int(:cycle, 0)
end

@testset "Pass and tiles" begin
    @test EarthData.Pass(1).tiles == String[]
    @test EarthData.Pass(1, ["1L", "2F"]).tiles == ["1L", "2F"]

    # CMR: "Tile must be in the format of \"\\d+[LRF]\"". Lowercase is rejected there too.
    @test_throws "integer followed by L, R or F" EarthData.Pass(1, ["2X"])
    @test_throws "integer followed by L, R or F" EarthData.Pass(1, ["2l"])
    @test_throws "integer followed by L, R or F" EarthData.Pass(1, ["L2"])
    @test_throws "positive integer" EarthData.Pass(-1)
    @test_throws "positive integer" EarthData.Pass(0)

    # CMR indexes each pass separately rather than repeating one key, which is why the query
    # is a pair vector.
    @test EarthData.cmr_passes(1) == ["passes[0][pass]" => "1"]
    @test EarthData.cmr_passes(EarthData.Pass(1, ["1L", "2F"])) ==
          ["passes[0][pass]" => "1", "passes[0][tiles]" => "1L,2F"]
    @test EarthData.cmr_passes([EarthData.Pass(1, ["1L"]), 2]) == [
        "passes[0][pass]" => "1",
        "passes[0][tiles]" => "1L",
        "passes[1][pass]" => "2",
    ]
end

@testset "Text parameters" begin
    @test EarthData.cmr_text(:version, "061") == "061"
    @test EarthData.cmr_text(:version, SubString("v061", 2)) == "061"
    # A `Symbol` is a reasonable way to write a fixed vocabulary, and round-trips exactly —
    # `Symbol("061")` included.
    @test EarthData.cmr_text(:day_night_flag, :day) == "day"
    @test EarthData.cmr_text(:version, Symbol("061")) == "061"
    @test isnothing(EarthData.cmr_text(:version, nothing))
    # CMR reads a repeated parameter as the union, so a vector stays legal.
    @test EarthData.cmr_text(:short_name, ["MCD43A3", "ATL03"]) == ["MCD43A3", "ATL03"]

    # The silent one. `version=061` in Julia is the integer 61, and CMR answers 0 hits for
    # "61" where "061" has millions — no error, just nothing found.
    @test_throws "takes text, not the number 61" EarthData.cmr_text(:version, 61)
    @test_throws "zero" EarthData.cmr_text(:version, 61)
    @test_throws ArgumentError EarthData.cmr_text(:short_name, 123)
    @test_throws ArgumentError EarthData.cmr_text(:day_night_flag, true)
    @test_throws "string or a `Symbol`" EarthData.cmr_text(:short_name, Dict())

    # CMR pattern-matches `day_night_flag` and accepts a value outside day/night/unspecified,
    # so the type stays `String` rather than becoming an enumeration the service does not
    # enforce.
    @test EarthData.cmr_text(:day_night_flag, "sideways") == "sideways"

    @test EarthData.param_family(:version) isa EarthData.TextParam

    # Not text, each for its own reason CMR gives:
    # `processing_level_id` holds the bare digits, so a number is the right value — "2"
    # matches thousands of collections and "02" matches none.
    @test EarthData.param_family(:processing_level_id) isa EarthData.FreeParam
    # `attribute` and `science_keywords` need a nested key: "Parameter [science_keywords]
    # must include a nested key".
    @test EarthData.param_family(:attribute) isa EarthData.FreeParam
    @test EarthData.param_family(:science_keywords) isa EarthData.FreeParam
    # "Parameter [variables] was not recognized."
    @test EarthData.param_family(:variables) isa EarthData.FreeParam
end

@testset "Parameters in a search" begin
    # What actually reaches the wire, for each family.
    for (key, value, expected) in (
        (:downloadable, true, "downloadable=true"),
        (:browsable, false, "browsable=false"),
        (:cloud_cover, (nothing, 30), "cloud_cover=$(HTTP.URIs.escapeuri(",30"))"),
        (:cycle, 1, "cycle=1"),
        # CMR pattern-matches this one and accepts `sideways`, so it is passed through
        # rather than checked against an enumeration the service does not enforce.
        (:day_night_flag, "sideways", "day_night_flag=sideways"),
    )
        requests = []
        responses = [HTTP.Response(200, [], cmr_response(["G1"], "granule"))]
        EarthData.granules(;
            key => value,
            requester=recording_requester(responses, requests),
        )
        @test occursin(expected, requests[1].body)
    end

    # A pass number identifies a granule only within a cycle, so CMR requires both.
    requests = []
    responses = [HTTP.Response(200, [], cmr_response(["G1"], "granule"))]
    EarthData.granules(;
        cycle=1,
        passes=EarthData.Pass(1, ["1L", "2F"]),
        requester=recording_requester(responses, requests),
    )
    body = requests[1].body
    @test occursin(HTTP.URIs.escapeuri("passes[0][pass]") * "=1", body)
    @test occursin(
        HTTP.URIs.escapeuri("passes[0][tiles]") * "=" * HTTP.URIs.escapeuri("1L,2F"),
        body,
    )
    @test occursin("cycle=1", body)

    # CMR: "Cycle value must be provided when searching with passes."
    @test_throws "needs a `cycle` as well" EarthData.granules(;
        passes=1,
        requester=recording_requester([], []),
    )
    # CMR: "There can only be one cycle value when searching with passes".
    @test_throws "exactly one `cycle`" EarthData.granules(;
        cycle=[1, 2],
        passes=1,
        requester=recording_requester([], []),
    )

    # The rejections happen before the request goes out, so no round-trip is spent on a
    # value CMR would refuse.
    for (key, value) in (
        (:downloadable, 42),
        (:cloud_cover, 5),
        (:cycle, 1.5),
        (:cycle, -1),
        # This one is a 200 with zero results rather than a 400, so nothing else would catch
        # it: CMR reads "61" literally and MCD43A3 is version "061".
        (:version, 61),
        (:short_name, 123),
    )
        requests = []
        @test_throws ArgumentError EarthData.granules(;
            key => value,
            requester=recording_requester([], requests),
        )
        @test isempty(requests)
    end
end
