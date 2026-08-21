using EarthData
using Test
using Documenter

include("schema_modules.jl")
include("show.jl")
include("search.jl")
include("retry.jl")
include("spatial.jl")  # uses search.jl's fake requester
include("temporal.jl")  # likewise
include("auth.jl")

# A pull request from a fork gets the workflow's `env:` keys, but with empty values —
# GitHub withholds secrets from forks. Test on non-emptiness, not on key presence, or we
# write a .netrc with a blank login and the DAAC answers with an HTML "Access denied" page.
have_earthdata_credentials() =
    !isempty(get(ENV, "EARTHDATA_USER", "")) && !isempty(get(ENV, "EARTHDATA_PW", ""))

function setup_env()
    if have_earthdata_credentials()
        @info "Setting up Earthdata credentials for Github Actions"
        EarthData.netrc!(ENV["EARTHDATA_USER"], ENV["EARTHDATA_PW"])
        return true
    end
    @info "No Earthdata credentials in the environment; skipping the tests that need them"
    return false
end


@testset "EarthData.jl" begin
    @testset "Granules" begin
        gg = granules(short_name="GEDI02_A")
        @test length(gg) == 10

        g = gg[1]
        @test g isa EarthData.Granules.UMM_G

        @test_throws ErrorException granules()

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

            # Test we can retrieve non-empty AWS credentials. The DAAC requires Earthdata
            # Login, so this half only runs where the credentials exist.
            if setup_env()
                EarthData.create_aws_config()
                @test !isempty(get(ENV, "AWS_ACCESS_KEY_ID", ""))
            end
        end
    end

    @testset "doctests" begin
        DocMeta.setdocmeta!(EarthData, :DocTestSetup, :(using EarthData); recursive=true)
        doctest(EarthData)
    end


end
