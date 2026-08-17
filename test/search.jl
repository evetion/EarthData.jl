using HTTP
using JSON3

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
            Dict("URL" => "s3://example-bucket/$id.h5", "Type" => "GET DATA"),
        ],
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
    @test requests[1].url == EarthData.collection_url
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

    @test EarthData.urls(granule) ==
          ["https://example.test/G1.h5", "s3://example-bucket/G1.h5"]
    @test EarthData.urls(granule; scheme=:https) == ["https://example.test/G1.h5"]
    @test EarthData.https_urls(granule) == ["https://example.test/G1.h5"]
    @test EarthData.s3_urls(granule) == ["s3://example-bucket/G1.h5"]
    @test EarthData.download_url(granule; scheme=:https) == "https://example.test/G1.h5"
    @test EarthData.download_url(granule; scheme=:ftp) === nothing
    @test EarthData.urls([granule, granule]; scheme=:s3) ==
          ["s3://example-bucket/G1.h5", "s3://example-bucket/G1.h5"]
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
    paths = EarthData.download(granules, folder; runner=cmd -> push!(commands, cmd))

    @test paths == [joinpath(folder, "G1.h5"), joinpath(folder, "G2.h5")]
    @test length(commands) == 1
    command_string = string(only(commands))
    @test occursin("-i", command_string)
    @test occursin("-c", command_string)
    @test occursin("-d", command_string)
    @test occursin(folder, command_string)
end
