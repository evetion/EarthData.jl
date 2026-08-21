using HTTP
using Test

@testset "System endpoints" begin
    # PROD is the default, so an unqualified search must be unchanged by this addition.
    @test EarthData.granule_url() == EarthData.granule_url(EarthData.PROD)
    @test occursin("cmr.earthdata.nasa.gov", EarthData.granule_url(EarthData.PROD))
    @test occursin("cmr.uat.earthdata.nasa.gov", EarthData.granule_url(EarthData.UAT))
    @test occursin("cmr.uat.earthdata.nasa.gov", EarthData.collection_url(EarthData.UAT))

    # The UMM version travels with the host: pointing at UAT must not silently downgrade the
    # schema the response is parsed against.
    for system in (EarthData.PROD, EarthData.UAT)
        @test occursin("granules.umm_json_v1_6_6", EarthData.granule_url(system))
        @test occursin("collections.umm_json_v1_17_0", EarthData.collection_url(system))
    end

    # `system` has to reach the request, not just the URL builder.
    for (search, concept, id) in (
        (EarthData.granules, "granule", "G1"),
        (EarthData.collections, "collection", "C1"),
    )
        requests = []
        responses = [HTTP.Response(200, [], cmr_response([id], concept))]
        search(;
            short_name="TEST",
            system=EarthData.UAT,
            requester=recording_requester(responses, requests),
        )
        @test occursin("cmr.uat.earthdata.nasa.gov", requests[1].url)
    end

    # `cmr_url` is a base URL, not a host, so a proxy or a local CMR is reachable — which a
    # bare hostname could not express, since the scheme and port would be baked in.
    local_cmr = EarthData.System(cmr_url="http://localhost:3003")
    @test EarthData.granule_url(local_cmr) ==
          "http://localhost:3003/search/granules.umm_json_v1_6_6"
    # Omitted fields fall back to production.
    @test local_cmr.edl_host == EarthData.PROD.edl_host

    # Default stays PROD when `system` is omitted.
    requests = []
    responses = [HTTP.Response(200, [], cmr_response(["G1"], "granule"))]
    EarthData.granules(;
        short_name="TEST",
        requester=recording_requester(responses, requests),
    )
    @test occursin("cmr.earthdata.nasa.gov", requests[1].url)
    @test !occursin("uat", requests[1].url)
end
