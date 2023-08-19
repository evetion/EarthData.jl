using EarthData
using Test
using Documenter

function setup_env()
    if "EARTHDATA_USER" in keys(ENV)
        @info "Setting up Earthdata credentials for Github Actions"
        SpaceLiDAR.netrc!(
            get(ENV, "EARTHDATA_USER", ""),
            get(ENV, "EARTHDATA_PW", ""),
        )
    end
end


@testset "EarthData.jl" begin
    @testset "Granules" begin
        gg = granules(short_name="GEDI02_A")
        @test length(gg) == 10

        g = gg[1]
        @test g isa EarthData.Granule

        @test_throws "Something went wrong: The CMR does not allow quer" granules()

    end

    @testset "Download" begin
        setup_env()
    end

    @testset "AWS" begin
        # Test package extension


        if isdefined(Base, :get_extension)
            # Test package extension is loaded
            @test isnothing(Base.get_extension(EarthData, :EarthDataAWSExt))
            using AWSS3
            @test !isnothing(Base.get_extension(EarthData, :EarthDataAWSExt))

            # Test we can retrieve non-empty AWS credentials
            setup_env()
            EarthData.create_aws_config()
            @test !isempty(get(ENV, "AWS_ACCESS_KEY_ID", ""))
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
