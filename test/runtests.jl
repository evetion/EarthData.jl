using EarthData
using Test
using Documenter


@testset "EarthData.jl" begin
    @testset "Granules" begin
        gg = granules(short_name="GEDI02_A")
        @test length(gg) == 10

        g = gg[1]
        @test g isa EarthData.Granule

        @test_throws "Something went wrong: The CMR does not allow quer" granules()
    end


    @testset "AWS" begin
        # Test package extension
        using AWSS3

        if "EARTHDATA_USER" in keys(ENV)
            @info "Setting up Earthdata credentials for Github Actions"
            SpaceLiDAR.netrc!(
                get(ENV, "EARTHDATA_USER", ""),
                get(ENV, "EARTHDATA_PW", ""),
            )
        end
    end

    @testset "doctests" begin
        DocMeta.setdocmeta!(
            EarthData,
            :DocTestSetup,
            :(using EarthData);
            recursive=true
        )
        doctest(EarthData)
    end


end
