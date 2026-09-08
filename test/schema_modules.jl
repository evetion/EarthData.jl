using Test
using EarthData

@testset "UMM schema modules" begin
    @test isdefined(EarthData, :GranuleSchema)
    @test EarthData.GranuleSchema.UMM_G <: EarthData.AbstractJSON
    @test !isdefined(EarthData, :UMM_G)
    @test EarthData.responsetype(EarthData.GranuleSchema.UMM_G) ===
          EarthData.GranuleSearchResponse

    @test isdefined(EarthData, :CollectionSchema)
    @test EarthData.CollectionSchema.UMM_C <: EarthData.AbstractJSON
    @test !isdefined(EarthData, :UMM_C)
    @test EarthData.responsetype(EarthData.CollectionSchema.UMM_C) ===
          EarthData.CollectionSearchResponse
    @test occursin("granules.umm_json_v1_6_6", EarthData.granule_url())
    @test occursin("collections.umm_json_v1_17_0", EarthData.collection_url())

    spec = EarthData.GranuleSchema.MetadataSpecificationType(
        "https://example.com/schema",
        "1.0",
        "UMM-G",
    )
    @test sprint(show, spec) == "EarthData.GranuleSchema.MetadataSpecificationType"
end

@testset "Deprecated schema module names" begin
    # The 0.2 names still resolve, so `EarthData.Granules.UMM_G` keeps working.
    # `@eval` defers the lookup to run time: a deprecated binding warns where the
    # reference is compiled, so `@test_deprecated` never sees it.
    @test @eval(EarthData.Granules) === EarthData.GranuleSchema
    @test @eval(EarthData.Collections) === EarthData.CollectionSchema
    @test @eval(EarthData.Granules.UMM_G) === EarthData.GranuleSchema.UMM_G
end
