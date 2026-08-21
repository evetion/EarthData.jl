using Test
using EarthData

@testset "UMM schema modules" begin
    @test isdefined(EarthData, :Granules)
    @test EarthData.Granules.UMM_G <: EarthData.AbstractJSON
    @test !isdefined(EarthData, :UMM_G)
    @test EarthData.responsetype(EarthData.Granules.UMM_G) ===
          EarthData.GranuleSearchResponse

    @test isdefined(EarthData, :Collections)
    @test EarthData.Collections.UMM_C <: EarthData.AbstractJSON
    @test !isdefined(EarthData, :UMM_C)
    @test EarthData.responsetype(EarthData.Collections.UMM_C) ===
          EarthData.CollectionSearchResponse
    @test occursin("granules.umm_json_v1_6_6", EarthData.granule_url())
    @test occursin("collections.umm_json_v1_17_0", EarthData.collection_url())

    spec = EarthData.Granules.MetadataSpecificationType(
        "https://example.com/schema",
        "1.0",
        "UMM-G",
    )
    @test sprint(show, spec) == "EarthData.Granules.MetadataSpecificationType"
end
