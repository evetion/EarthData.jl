using JSON3

@testset "Show methods" begin
    granule = JSON3.read(
        JSON3.write(
            Dict(
                "CollectionReference" => Dict("ShortName" => "TEST", "Version" => "001"),
                "GranuleUR" => "G1",
                "MetadataSpecification" => Dict(
                    "URL" => "https://example.test",
                    "Version" => "1.6.6",
                    "Name" => "UMM-G",
                ),
                "ProviderDates" =>
                    [Dict("Type" => "Insert", "Date" => "2020-01-01T00:00:00Z")],
            ),
        ),
        EarthData.Granules.UMM_G,
    )
    @test sprint(show, granule) == "TEST: G1"
    @test sprint(show, MIME"text/plain"(), granule) == "TEST: G1"

    granule_without_reference = JSON3.read(
        JSON3.write(
            Dict(
                "CollectionReference" => Dict(),
                "GranuleUR" => "G2",
                "MetadataSpecification" => Dict(
                    "URL" => "https://example.test",
                    "Version" => "1.6.6",
                    "Name" => "UMM-G",
                ),
                "ProviderDates" =>
                    [Dict("Type" => "Insert", "Date" => "2020-01-01T00:00:00Z")],
            ),
        ),
        EarthData.Granules.UMM_G,
    )
    @test sprint(show, granule_without_reference) == "G2"

    collection = JSON3.read(
        JSON3.write(
            Dict(
                "ScienceKeywords" =>
                    [Dict("Category" => "EARTH SCIENCE", "Topic" => "TEST", "Term" => "TEST")],
                "DataCenters" => [Dict("ShortName" => "TEST", "Roles" => ["ARCHIVER"])],
                "MetadataSpecification" => Dict(
                    "URL" => "https://example.test",
                    "Version" => "1.17.0",
                    "Name" => "UMM-C",
                ),
                "SpatialExtent" => Dict("GranuleSpatialRepresentation" => "NO_SPATIAL"),
                "Version" => "1",
                "TemporalExtents" => [Dict()],
                "EntryTitle" => "Test collection",
                "Platforms" => [Dict("ShortName" => "TEST")],
                "CollectionProgress" => "ACTIVE",
                "ProcessingLevel" => Dict("Id" => "1"),
                "ShortName" => "TEST",
                "Abstract" => "A test collection",
                "DOI" => Dict(),
            ),
        ),
        EarthData.Collections.UMM_C,
    )
    @test sprint(show, collection) == "TEST: Test collection"
    @test sprint(show, MIME"text/plain"(), collection) == "TEST: Test collection"
end
