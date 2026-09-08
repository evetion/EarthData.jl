using Test
using EarthData
using JSON3

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

@testset "CMR meta" begin
    # Field names are snake_case where CMR sends kebab-case.
    granule_json = """
    {"concept-type":"granule","concept-id":"G3986520887-LPCLOUD","revision-id":1,
     "native-id":"GEDI02_A_2019094180555","collection-concept-id":"C3974616071-LPCLOUD",
     "provider-id":"LPCLOUD","format":"application/vnd.nasa.cmr.umm+json",
     "revision-date":"2026-01-28T21:36:20.329Z"}
    """
    meta = JSON3.read(granule_json, EarthData.GranuleMeta)
    @test meta.concept_id == "G3986520887-LPCLOUD"
    @test meta.collection_concept_id == "C3974616071-LPCLOUD"
    @test meta.revision_id == 1
    @test meta.provider_id == "LPCLOUD"
    @test meta.concept_type == "granule"

    # A collection carries the service capabilities and `s3-links` that a granule has no
    # equivalent of, and no `collection-concept-id` of its own.
    required = """
     "concept-type":"collection","concept-id":"C2142771958-LPCLOUD","revision-id":80,
     "native-id":"GEDI02_A","provider-id":"LPCLOUD","user-id":"thouska",
     "format":"application/vnd.nasa.cmr.umm+json",
     "revision-date":"2026-01-28T21:36:20.329Z",
     "deleted":false,"has-combine":false,"has-formats":false,
     "has-spatial-subsetting":true,"has-temporal-subsetting":true,
     "has-transforms":false,"has-variables":true
    """
    optional = """
     ,"s3-links":["s3://lp-prod-protected/GEDI02_A.002"],
     "associations":{"variables":["V2839411263-LPCLOUD"]}
    """

    collection = JSON3.read("{$required$optional}", EarthData.CollectionMeta)
    @test collection.concept_id == "C2142771958-LPCLOUD"
    @test collection.user_id == "thouska"
    @test collection.has_variables
    @test !collection.deleted
    @test collection.s3_links == ["s3://lp-prod-protected/GEDI02_A.002"]
    @test collection.associations["variables"] == ["V2839411263-LPCLOUD"]
    @test !hasproperty(collection, :collection_concept_id)

    # `associations` and `s3-links` are absent from many records.
    bare = JSON3.read("{$required}", EarthData.CollectionMeta)
    @test isnothing(bare.s3_links)
    @test isnothing(bare.associations)
    @test bare.concept_id == "C2142771958-LPCLOUD"
end
