using HTTP
using Test

# Every rejection below is a CMR HTTP 400 without the conversion, except where noted. The
# wording in each `@test_throws` is what the user has to act on.
#
# A parameter is checked in two steps, so the tests are too: `GranuleRequest` /
# `CollectionRequest` normalize and reject what the user wrote, and `cmr_pairs` turns a
# stored field into what goes on the wire.

# The value a request stores for one keyword, and the pairs it becomes.
granule_field(key, value) = getfield(EarthData.GranuleRequest(; key => value), key)
collection_field(key, value) = getfield(EarthData.CollectionRequest(; key => value), key)
granule_wire(key, value) = EarthData.cmr_pairs(key, granule_field(key, value))

@testset "Boolean parameters" begin
    @test granule_wire(:downloadable, true) == ["downloadable" => "true"]
    @test granule_wire(:downloadable, false) == ["downloadable" => "false"]
    @test isnothing(granule_field(:downloadable, nothing))

    # A string is the escape hatch, as in every other family. CMR accepts spellings this
    # module does not build — `TRUE` and `True` among them — so the string is passed on and
    # CMR judges it, rather than being checked against a list stricter than the service.
    @test granule_wire(:downloadable, "true") == ["downloadable" => "true"]
    @test granule_wire(:downloadable, "TRUE") == ["downloadable" => "TRUE"]
    @test granule_wire(:downloadable, "unset") == ["downloadable" => "unset"]

    # `1` is not a synonym for `true` here — CMR rejects it outright, so `BoolParam` has no
    # `Integer` member and the field type is the whole check.
    @test_throws "takes Bool or String" EarthData.GranuleRequest(downloadable=1)
    @test_throws "takes Bool or String" EarthData.GranuleRequest(downloadable=42)

    # Naming the parameter matters: the message is the only clue which keyword was wrong.
    @test_throws "cloud_hosted" EarthData.CollectionRequest(cloud_hosted=0)
    # And the field docstring says what the parameter is, so the message explains itself.
    @test_throws "held in the cloud" EarthData.CollectionRequest(cloud_hosted=0)
end

@testset "Numeric range parameters" begin
    # CMR answers a single value with "The min and max values of a numeric range cannot both
    # be nil", which does not say what to do about it.
    @test_throws "takes a (min, max) range" EarthData.GranuleRequest(cloud_cover=5)

    @test granule_wire(:cloud_cover, (0.2, nothing)) == ["cloud_cover" => "0.2,"]
    @test granule_wire(:cloud_cover, (nothing, 30)) == ["cloud_cover" => ",30"]
    @test granule_wire(:cloud_cover, (0.5, 20.5)) == ["cloud_cover" => "0.5,20.5"]
    @test granule_wire(:equator_crossing_longitude, (-10, 10)) ==
          ["equator_crossing_longitude" => "-10,10"]

    # A range with no bounds is not a search, and a backwards one silently matches nothing.
    @test_throws "needs at least one bound" EarthData.GranuleRequest(
        cloud_cover=(nothing, nothing),
    )
    @test_throws "ends below where it starts" EarthData.GranuleRequest(
        cloud_cover=(30, 10),
    )

    # `string(1e-5)` is "1.0e-5", which CMR rejects; `coord_string` writes plain decimals.
    @test granule_wire(:cloud_cover, (1e-5, nothing)) == ["cloud_cover" => "0.00001,"]

    @test granule_wire(:cloud_cover, "0.2,30") == ["cloud_cover" => "0.2,30"]
    @test_throws ArgumentError EarthData.GranuleRequest(cloud_cover=Dict())
end

@testset "Positive integer parameters" begin
    @test granule_wire(:cycle, 1) == ["cycle" => "1"]
    @test granule_wire(:cycle, "1") == ["cycle" => "1"]

    # CMR: "Cycle must be a positive integer, but was [1.5]".
    @test_throws "must be a positive integer" EarthData.GranuleRequest(cycle=1.5)
    @test_throws "must be a positive integer" EarthData.GranuleRequest(cycle=-1)
    @test_throws "must be a positive integer" EarthData.GranuleRequest(cycle=0)
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

    # A pass number identifies a granule only within a cycle, so every request below carries
    # one; `cycle` on its own is tested above.
    passes_field(value) = EarthData.GranuleRequest(cycle=1, passes=value).passes
    passes_wire(value) = EarthData.cmr_pairs(:passes, passes_field(value))

    # A bare number is one pass, so `passes=1` needs no wrapper.
    @test passes_field(1) == [EarthData.Pass(1)]

    # CMR indexes each pass separately rather than repeating one key, which is why the query
    # is a pair vector.
    @test passes_wire(1) == ["passes[0][pass]" => "1"]
    @test passes_wire(EarthData.Pass(1, ["1L", "2F"])) ==
          ["passes[0][pass]" => "1", "passes[0][tiles]" => "1L,2F"]
    @test passes_wire([EarthData.Pass(1, ["1L"]), 2]) == [
        "passes[0][pass]" => "1",
        "passes[0][tiles]" => "1L",
        "passes[1][pass]" => "2",
    ]
end

@testset "Text parameters" begin
    @test granule_field(:version, "061") == "061"
    # A `SubString` is not a `String`, so it is normalized rather than rejected.
    @test granule_field(:version, SubString("v061", 2)) == "061"
    # A `Symbol` is a reasonable way to write a fixed vocabulary, and round-trips exactly —
    # `Symbol("061")` included.
    @test granule_field(:day_night_flag, :day) == "day"
    @test granule_field(:version, Symbol("061")) == "061"
    @test isnothing(granule_field(:version, nothing))
    # CMR reads a repeated parameter as the union, so a vector stays legal.
    @test granule_field(:short_name, ["MCD43A3", "ATL03"]) == ["MCD43A3", "ATL03"]
    @test granule_wire(:short_name, ["MCD43A3", "ATL03"]) ==
          ["short_name" => "MCD43A3", "short_name" => "ATL03"]

    # The silent one. `version=061` in Julia is the integer 61, and CMR answers 0 hits for
    # "61" where "061" has millions — no error, just nothing found. The field docstring
    # carries the zero-padding warning, so the message says why a number cannot work.
    @test_throws "takes text, not the number 61" EarthData.GranuleRequest(version=61)
    @test_throws "zero-padded" EarthData.GranuleRequest(version=61)
    @test_throws ArgumentError EarthData.GranuleRequest(short_name=123)
    @test_throws ArgumentError EarthData.GranuleRequest(day_night_flag=true)
    @test_throws "takes Vector{String} or String" EarthData.GranuleRequest(
        short_name=Dict(),
    )

    # CMR pattern-matches `day_night_flag` and accepts a value outside day/night/unspecified,
    # so the type stays `String` rather than becoming an enumeration the service does not
    # enforce.
    @test granule_field(:day_night_flag, "sideways") == "sideways"

    @test fieldtype(EarthData.GranuleRequest, :version) === EarthData.TextParam

    # Not text, each for its own reason CMR gives:
    # `processing_level_id` holds the bare digits, so a number is the right value — "2"
    # matches thousands of collections and "02" matches none.
    @test collection_field(:processing_level_id, 2) == 2
    # `attribute` and `science_keywords` need a nested key: "Parameter [science_keywords]
    # must include a nested key".
    for key in (:attribute, :science_keywords, :variables)
        @test fieldtype(EarthData.CollectionRequest, key) === EarthData.FreeParam
    end
    # `two_d_coordinate_system` is `name:coords`, so it is passed on as written.
    @test fieldtype(EarthData.GranuleRequest, :two_d_coordinate_system) ===
          EarthData.FreeParam
end

@testset "Every parameter is declared once" begin
    requests = (EarthData.GranuleRequest, EarthData.CollectionRequest)

    # A field's type is its family, and its docstring is what the parameter means. Both are
    # what conversion and the error messages are built from, so a field missing either is a
    # parameter that documents itself nowhere.
    known = (
        EarthData.TextParam,
        EarthData.BoolParam,
        EarthData.NumericRangeParam,
        EarthData.PositiveIntParam,
        EarthData.PassesParam,
        EarthData.DateParam,
        EarthData.DateRangeParam,
        EarthData.SpatialParam,
    )
    for R in requests
        docs = EarthData.fielddocs(R)
        for name in fieldnames(R)
            @test fieldtype(R, name) in known
            @test haskey(docs, name)
            @test !isempty(strip(docs[name]))
        end
    end

    # Every family is reached by at least one parameter, so none of these types is declared
    # and then never used. `SpatialParam` is skipped: it and `FreeParam` are both `Any`, so
    # `fieldtype` cannot tell them apart and `spatial_params` names the spatial ones instead.
    for T in known
        T === EarthData.SpatialParam && continue
        @test any(R -> !isempty(param_names(R, T)), requests)
    end

    # `updated_since` is the one date parameter CMR takes as a single instant, so on each
    # request it is the whole instant family and is absent from the range family.
    for R in requests
        @test param_names(R, EarthData.DateParam) == (:updated_since,)
        @test :updated_since ∉ param_names(R, EarthData.DateRangeParam)
    end

    # Every parameter is reachable with no arguments at all, i.e. each field has a default.
    @test EarthData.GranuleRequest() isa EarthData.GranuleRequest
    @test EarthData.CollectionRequest() isa EarthData.CollectionRequest

    # A misspelled keyword names itself, rather than listing every field of the request.
    @test_throws "Unknown keyword argument(s): nonsense" EarthData.granules(
        nonsense=1,
        requester=recording_requester([], []),
    )
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
