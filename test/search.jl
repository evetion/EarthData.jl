using Dates
using Extents
using HTTP
using JSON3
import GeoInterface as GI

# A rectangle that counts how many times its extent is read, so a test can assert conversion
# happened once rather than once per page.
struct CountingGeometry
    extent::Extent
    count::Ref{Int}
end
GI.isgeometry(::Type{CountingGeometry}) = true
GI.geomtrait(::CountingGeometry) = GI.RectangleTrait()
function GI.extent(::GI.RectangleTrait, g::CountingGeometry)
    g.count[] += 1
    return g.extent
end

function cmr_meta(id, concept_type)
    Dict(
        "concept-type" => concept_type,
        "concept-id" => id,
        "revision-id" => 1,
        "native-id" => id,
        "provider-id" => "TEST",
        "format" => "application/json",
        "revision-date" => "2020-01-01T00:00:00Z",
    )
end

function granule_umm(id)
    Dict(
        "CollectionReference" => Dict("ShortName" => "TEST", "Version" => "001"),
        "GranuleUR" => id,
        "RelatedUrls" => [
            Dict("URL" => "https://example.test/$id.h5", "Type" => "GET DATA"),
            # A real record types the S3 copy of the same file separately, and carries
            # several URLs that are not the data at all.
            Dict(
                "URL" => "s3://example-bucket/$id.h5",
                "Type" => "GET DATA VIA DIRECT ACCESS",
            ),
            Dict(
                "URL" => "https://example.test/s3credentials",
                "Type" => "VIEW RELATED INFORMATION",
            ),
        ],
        "DataGranule" => Dict(
            "DayNightFlag" => "DAY",
            "ProductionDateTime" => "2020-01-01T00:00:00Z",
            "ArchiveAndDistributionInformation" =>
                [Dict("Name" => "$id.h5", "Size" => 1.5, "SizeUnit" => "MB")],
        ),
        "MetadataSpecification" =>
            Dict("URL" => "https://example.test", "Version" => "1.6.6", "Name" => "UMM-G"),
        "ProviderDates" => [Dict("Type" => "Insert", "Date" => "2020-01-01T00:00:00Z")],
    )
end

function collection_umm(id)
    Dict(
        "ScienceKeywords" =>
            [Dict("Category" => "EARTH SCIENCE", "Topic" => "TEST", "Term" => "TEST")],
        "DataCenters" => [Dict("ShortName" => "TEST", "Roles" => ["ARCHIVER"])],
        "MetadataDates" => [Dict("Type" => "CREATE")],
        "MetadataSpecification" =>
            Dict("URL" => "https://example.test", "Version" => "1.17.0", "Name" => "UMM-C"),
        "SpatialExtent" => Dict("GranuleSpatialRepresentation" => "NO_SPATIAL"),
        "Version" => "1",
        "TemporalExtents" => [Dict()],
        "EntryTitle" => id,
        "Platforms" => [Dict("ShortName" => "TEST")],
        "CollectionProgress" => "ACTIVE",
        "ProcessingLevel" => Dict("Id" => "1"),
        "ShortName" => id,
        "Abstract" => "Test collection",
        "DOI" => Dict(),
    )
end

struct SizelessItem <: EarthData.AbstractJSON
    DataGranule::Nothing
end

# Enough of a granule to exercise `granule_size`'s unit handling directly.
struct SizeEntry
    Name::String
    Size::Union{Nothing,Float64}
    SizeUnit::Union{Nothing,String}
    SizeInBytes::Union{Nothing,Int}
end
struct SizedDataGranule
    ArchiveAndDistributionInformation::Vector{SizeEntry}
end
struct SizedItem <: EarthData.AbstractJSON
    DataGranule::SizedDataGranule
end
sized_item(entries...) = SizedItem(SizedDataGranule(collect(entries)))

function cmr_response(ids, concept_type; hits=length(ids))
    umm = concept_type == "granule" ? granule_umm : collection_umm
    JSON3.write(
        Dict(
            "hits" => hits,
            "took" => 1,
            "items" => [
                Dict("meta" => cmr_meta(id, concept_type), "umm" => umm(id)) for id in ids
            ],
        ),
    )
end

function recording_requester(responses, requests)
    function requester(
        method,
        url,
        headers;
        body=nothing,
        query=nothing,
        verbose=false,
        status_exception=false,
    )
        push!(
            requests,
            (;
                method=String(method),
                url=url,
                headers=Dict(headers),
                body=isnothing(body) ? nothing : String(body),
                query=query,
                verbose=verbose,
                status_exception=status_exception,
            ),
        )
        popfirst!(responses)
    end
end

@testset "CMR request" begin
    requests = []
    responses = [
        HTTP.Response(
            200,
            ["CMR-Search-After" => "next-page"],
            cmr_response(["G1", "G2"], "granule"; hits=3),
        ),
        HTTP.Response(200, [], cmr_response(["G3"], "granule"; hits=3)),
    ]

    result = EarthData.request(
        "https://example.test/granules",
        Dict("short_name" => "TEST"),
        EarthData.Granules.UMM_G;
        page_size=2,
        all=true,
        requester=recording_requester(responses, requests),
    )

    @test getproperty.(result, :GranuleUR) == ["G1", "G2", "G3"]
    @test length(requests) == 2
    @test requests[1].method == "POST"
    @test requests[1].headers["Client-Id"] == "EarthData.jl"
    @test requests[1].headers["Content-Type"] == "application/x-www-form-urlencoded"
    @test requests[1].query === nothing
    @test occursin("short_name=TEST", requests[1].body)
    @test occursin("page_size=2", requests[1].body)
    @test occursin("page_num=1", requests[1].body)
    @test requests[2].headers["CMR-Search-After"] == "next-page"
    # CMR answers HTTP 400 "page_num is not allowed with search-after" if both are sent, so
    # the second page must carry the header and *not* `page_num`.
    @test !occursin("page_num", requests[2].body)
    @test occursin("page_size=2", requests[2].body)
    @test occursin("short_name=TEST", requests[2].body)
    @test isempty(responses)
end

@testset "CMR GET pagination drops page_num too" begin
    requests = []
    responses = [
        HTTP.Response(
            200,
            ["CMR-Search-After" => "next-page"],
            cmr_response(["G1"], "granule"; hits=2),
        ),
        HTTP.Response(200, [], cmr_response(["G2"], "granule"; hits=2)),
    ]

    EarthData.request(
        "https://example.test/granules",
        Dict("short_name" => "TEST"),
        EarthData.Granules.UMM_G;
        page_size=1,
        all=true,
        method=:GET,
        requester=recording_requester(responses, requests),
    )

    @test requests[1].query["page_num"] == 1
    @test !haskey(requests[2].query, "page_num")
    @test requests[2].query["page_size"] == 1
end

@testset "CMR GET compatibility" begin
    requests = []
    responses = [HTTP.Response(200, [], cmr_response(["G1"], "granule"))]

    result = EarthData.request(
        "https://example.test/granules",
        Dict("short_name" => "TEST"),
        EarthData.Granules.UMM_G;
        method=:GET,
        requester=recording_requester(responses, requests),
    )

    @test getproperty.(result, :GranuleUR) == ["G1"]
    @test requests[1].method == "GET"
    @test requests[1].body === nothing
    @test requests[1].query["short_name"] == "TEST"
    @test requests[1].query["page_size"] == 10
end

@testset "Granule spatial parameters" begin
    for (key, value) in (
        :bounding_box => "-51.0,66.0,-49.0,68.0",
        :point => "-50.0,67.0",
        :line => "-51.0,66.0,-49.0,68.0",
        :circle => "-50.0,67.0,10000",
        :polygon => "-51,66,-49,66,-49,68,-51,66",
    )
        requests = []
        responses = [HTTP.Response(200, [], cmr_response(["G1"], "granule"))]

        result = EarthData.granules(;
            short_name="TEST",
            key => value,
            requester=recording_requester(responses, requests),
        )

        @test getproperty.(result, :GranuleUR) == ["G1"]
        # The value must reach CMR verbatim: a bounding box whose edges are parallels and
        # meridians is not the same selection as the polygon with the same corners, whose
        # edges CMR treats as great-circle arcs.
        @test occursin("$(key)=$(HTTP.URIs.escapeuri(value))", requests[1].body)
    end
end

@testset "Collections search" begin
    requests = []
    responses = [HTTP.Response(200, [], cmr_response(["C1"], "collection"))]

    result = EarthData.collections(
        short_name="C1";
        requester=recording_requester(responses, requests),
    )

    @test result isa Vector{EarthData.Collections.UMM_C}
    @test only(result).ShortName == "C1"
    @test only(result).MetadataDates[1].Date === nothing
    @test requests[1].url == EarthData.collection_url()
    @test occursin("short_name=C1", requests[1].body)
    @test_throws ArgumentError EarthData.collections(not_a_cmr_keyword=1)
end

@testset "Related URL helpers" begin
    requests = []
    responses = [HTTP.Response(200, [], cmr_response(["G1"], "granule"))]
    granule = only(
        EarthData.request(
            "https://example.test/granules",
            Dict("short_name" => "TEST"),
            EarthData.Granules.UMM_G;
            requester=recording_requester(responses, requests),
        ),
    )

    @test EarthData.urls(granule) == [
        "https://example.test/G1.h5",
        "s3://example-bucket/G1.h5",
        "https://example.test/s3credentials",
    ]
    @test EarthData.urls(granule; scheme=:https) ==
          ["https://example.test/G1.h5", "https://example.test/s3credentials"]
    @test EarthData.https_urls(granule) ==
          ["https://example.test/G1.h5", "https://example.test/s3credentials"]
    @test EarthData.s3_urls(granule) == ["s3://example-bucket/G1.h5"]
    @test EarthData.download_url(granule; scheme=:https) == "https://example.test/G1.h5"
    @test EarthData.download_url(granule; scheme=:ftp) === nothing
    @test EarthData.urls([granule, granule]; scheme=:s3) ==
          ["s3://example-bucket/G1.h5", "s3://example-bucket/G1.h5"]

    # Filtering on the scheme alone keeps the credentials endpoint; filtering on the type
    # is what isolates the file.
    @test EarthData.data_urls(granule) == ["https://example.test/G1.h5"]
    @test EarthData.urls(granule; type="GET DATA VIA DIRECT ACCESS") ==
          ["s3://example-bucket/G1.h5"]
    @test EarthData.urls(granule; scheme=:https, type="GET DATA VIA DIRECT ACCESS") == []
    @test EarthData.urls(granule; type="NOT A TYPE") == []
    @test EarthData.download_url(granule; type="GET DATA") == "https://example.test/G1.h5"
    @test EarthData.data_urls([granule, granule]) ==
          ["https://example.test/G1.h5", "https://example.test/G1.h5"]
end

@testset "Granule sizes" begin
    requests = []
    responses = [HTTP.Response(200, [], cmr_response(["G1"], "granule"))]
    granule = only(
        EarthData.request(
            "https://example.test/granules",
            Dict("short_name" => "TEST"),
            EarthData.Granules.UMM_G;
            requester=recording_requester(responses, requests),
        ),
    )

    # `Size` is 1.5 with `SizeUnit` "MB", so the unit has to be read: taking the number
    # alone would report 1 byte where the file is 1.5 MiB.
    @test EarthData.granule_size(granule) == round(Int, 1.5 * 1024^2)

    @test EarthData.size_unit_factor("Bytes") == 1
    @test EarthData.size_unit_factor("b") == 1
    @test EarthData.size_unit_factor("KB") == 1024
    @test EarthData.size_unit_factor(" mb ") == 1024^2
    @test EarthData.size_unit_factor("GB") == 1024^3
    @test EarthData.size_unit_factor("TB") == 1024^4
    @test_throws ArgumentError EarthData.size_unit_factor("furlongs")

    # ATL06 reports `Size` with `SizeUnit` "NA", which means the provider recorded no unit
    # rather than that the number is bytes. It has no factor, so the entry is skipped.
    @test EarthData.size_unit_factor("NA") === nothing
    @test EarthData.granule_size(sized_item(SizeEntry("f.h5", 16.0, "NA", nothing))) ===
          nothing

    # A sibling entry that does carry a usable size still counts.
    @test EarthData.granule_size(
        sized_item(
            SizeEntry("f.h5", 16.0, "NA", nothing),
            SizeEntry("f.png", nothing, nothing, 2048),
        ),
    ) == 2048

    # A record with no size information reports nothing rather than zero, so a caller can
    # tell "not stated" from "empty".
    @test EarthData.granule_size(SizelessItem(nothing)) === nothing
end

@testset "Batch downloads" begin
    io = IOBuffer()
    EarthData.write_urls(io, ["https://example.test/G1.h5", "https://example.test/G2.h5"])
    @test String(take!(io)) == "https://example.test/G1.h5\nhttps://example.test/G2.h5\n"

    list_file = EarthData.write_urls(["https://example.test/G1.h5"])
    try
        @test read(list_file, String) == "https://example.test/G1.h5\n"
    finally
        rm(list_file; force=true)
    end

    requests = []
    responses = [HTTP.Response(200, [], cmr_response(["G1", "G2"], "granule"))]
    granules = EarthData.request(
        "https://example.test/granules",
        Dict("short_name" => "TEST"),
        EarthData.Granules.UMM_G;
        requester=recording_requester(responses, requests),
    )

    commands = Cmd[]
    folder = mktempdir()
    paths = EarthData.download(
        granules,
        folder;
        type="GET DATA",
        runner=cmd -> push!(commands, cmd),
    )

    @test paths == [joinpath(folder, "G1.h5"), joinpath(folder, "G2.h5")]
    @test length(commands) == 1

    # Without the type filter every HTTPS related URL is fetched, including the cloud
    # credentials endpoint — which is why `type` exists.
    unfiltered = EarthData.download(granules, folder; runner=Returns(nothing))
    @test joinpath(folder, "s3credentials") in unfiltered
    command_string = string(only(commands))
    @test occursin("-i", command_string)
    @test occursin("-c", command_string)
    @test occursin("-d", command_string)
    @test occursin(folder, command_string)
end

@testset "Typed requests" begin
    # Conversion happens when the request is built, so a field holds what will be sent.
    @test EarthData.GranuleRequest(
        bounding_box=Extent(X=(-51.0, -49.0), Y=(66.0, 68.0)),
    ).bounding_box == "-51,66,-49,68"
    @test EarthData.GranuleRequest(temporal=Date(2019, 4, 18)).temporal ==
          "2019-04-18T00:00:00Z"
    @test EarthData.GranuleRequest(temporal=(Date(2019, 4, 18), nothing)).temporal ==
          "2019-04-18T00:00:00Z,"

    # A string is what CMR takes, so it survives verbatim rather than being reformatted.
    @test EarthData.GranuleRequest(bounding_box="-51.0,66.0,-49.0,68.0").bounding_box ==
          "-51.0,66.0,-49.0,68.0"

    # A number or a boolean reaches CMR as text either way, so a field holds the text and no
    # field has to be typed `Any`. What goes on the wire is unchanged.
    @test EarthData.GranuleRequest(downloadable=true).downloadable == "true"
    @test EarthData.GranuleRequest(cloud_cover=5).cloud_cover == "5"
    @test EarthData.GranuleRequest(sort_key=["-start_date"]).sort_key == ["-start_date"]
    @test EarthData.GranuleRequest(cloud_cover="0,20").cloud_cover == "0,20"

    # A vector of geometries is a repeated parameter, which CMR reads as their union.
    @test EarthData.GranuleRequest(point=[(-50.0, 67.0), (-40.0, 60.0)]).point ==
          ["-50,67", "-40,60"]

    # `fieldnames` is how the accepted keywords are documented, and the two endpoints do not
    # accept the same ones: `production_date` is granule-only, `has_granules_created_at`
    # collection-only. Conversion follows the field list, so each struct converts its own.
    @test :bounding_box in fieldnames(EarthData.GranuleRequest)
    @test :production_date in fieldnames(EarthData.GranuleRequest)
    @test :has_granules_created_at ∉ fieldnames(EarthData.GranuleRequest)
    @test :has_granules_created_at in fieldnames(EarthData.CollectionRequest)
    @test :production_date ∉ fieldnames(EarthData.CollectionRequest)
    @test EarthData.CollectionRequest(
        has_granules_created_at=Date(2019, 4, 18),
    ).has_granules_created_at == "2019-04-18T00:00:00Z"

    # A value CMR cannot be sent fails when the request is built, naming the parameter,
    # rather than as a MethodError from inside the HTTP layer once a search is under way.
    @test_throws ArgumentError EarthData.GranuleRequest(temporal=2019)
    @test_throws "cannot send a Nothing to CMR" EarthData.GranuleRequest(
        temporal=[Date(2019, 1, 1), nothing],
    )

    # A request that constrains nothing sends nothing, rather than a parameter per field.
    @test EarthData.GranuleRequest() isa EarthData.GranuleRequest
    @test isempty(EarthData.cmr_dict(EarthData.GranuleRequest()))

    # Parameters that apply to any search are not fields of either request struct, so they
    # ride alongside rather than through the constructor.
    query = EarthData.cmr_query_params(EarthData.GranuleRequest; short_name="T", token="abc")
    @test query["short_name"] == "T"
    @test query["token"] == "abc"
    # They are not converted either, so a numeric one stays a number: the merged dictionary
    # holds both, which is why it cannot be narrowed to what a request field holds.
    numbered = EarthData.cmr_query_params(
        EarthData.GranuleRequest;
        short_name="T",
        page_size=25,
        pretty=true,
    )
    @test numbered["page_size"] === 25
    @test numbered["pretty"] === true

    # A keyword belonging to neither is an error: CMR ignores what it does not recognise, so
    # a typo would otherwise widen the search instead of failing.
    @test_throws ArgumentError EarthData.cmr_query_params(
        EarthData.GranuleRequest;
        not_a_cmr_keyword=1,
    )
    # ...including a keyword the *other* endpoint accepts.
    @test_throws ArgumentError EarthData.cmr_query_params(
        EarthData.CollectionRequest;
        production_date=Date(2019, 1, 1),
    )
end

@testset "Conversion runs once per search" begin
    # Paging re-sends the query for every page, so a geometry converted per request would be
    # re-converted per page — for a polygon that means re-winding the ring each time.
    conversions = Ref(0)
    ext = Extent(X=(-51.0, -49.0), Y=(66.0, 68.0))
    counted = CountingGeometry(ext, conversions)

    requests = []
    responses = [
        HTTP.Response(
            200,
            ["CMR-Search-After" => "page-2"],
            cmr_response(["G1"], "granule"; hits=2),
        ),
        HTTP.Response(200, [], cmr_response(["G2"], "granule"; hits=2)),
    ]
    result = EarthData.granules(
        bounding_box=counted,
        page_size=1,
        all=true,
        requester=recording_requester(responses, requests),
    )

    @test length(result) == 2
    @test length(requests) == 2
    @test conversions[] == 1
    # Both pages carry the same converted value; only the paging parameters differ.
    @test occursin("bounding_box=-51%2C66%2C-49%2C68", requests[1].body)
    @test occursin("bounding_box=-51%2C66%2C-49%2C68", requests[2].body)
end
