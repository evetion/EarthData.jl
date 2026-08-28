using EarthData
using Test
using Documenter
using Dates

include("schema_modules.jl")
include("show.jl")
include("search.jl")
include("retry.jl")
include("spatial.jl")  # uses search.jl's fake requester
include("system.jl")  # likewise
include("temporal.jl")  # likewise
include("geointerface.jl")
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

# How long the live S3-credentials call may spend retrying. `with_retries` defaults to 60
# attempts at up to 60 s of backoff, which suits a download waiting out a maintenance
# window but means a CI job spends over an hour on an unreachable endpoint before saying so.
const s3_credentials_deadline_s = 120.0


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

            # The warm-cache branch reuses unexpired credentials from the environment.
            # `AWSCredentials` names its keyword `expiry` and absorbs no others, so the
            # branch raised instead of running.
            ext = Base.get_extension(EarthData, :EarthDataAWSExt)
            env = Dict{String,String}()
            creds = AWSS3.AWSCredentials("id", "secret", "token"; expiry=DateTime(2030))
            ext.set_env!(creds, env)
            @test env["AWS_SESSION_EXPIRES"] == "2030-01-01T00:00:00"
            @test DateTime(env["AWS_SESSION_EXPIRES"]) == DateTime(2030)

            withenv(
                "AWS_ACCESS_KEY_ID" => "cached-id",
                "AWS_SECRET_ACCESS_KEY" => "cached-secret",
                "AWS_SESSION_TOKEN" => "cached-token",
                "AWS_SESSION_EXPIRES" => string(DateTime(2030)),
            ) do
                config = EarthData.create_aws_config()
                @test config.credentials.access_key_id == "cached-id"
                @test config.credentials.expiry == DateTime(2030)
            end

            # Test we can retrieve non-empty AWS credentials. The DAAC requires Earthdata
            # Login, so this half only runs where the credentials exist.
            if setup_env()
                # A live call against NASA, so it fails when NASA is down. That is a real
                # failure — the credentials genuinely could not be fetched — and it stays
                # one; an unreachable host only changes the message, so whoever reads the
                # log knows to rerun rather than to go looking for the bug.
                try
                    EarthData.create_aws_config(
                        deadline=time() + s3_credentials_deadline_s,
                    )
                    @test !isempty(get(ENV, "AWS_ACCESS_KEY_ID", ""))
                catch err
                    host = unreachable_host(err)
                    isnothing(host) && rethrow()
                    error("""
                        Could not reach $(host) within $(Int(s3_credentials_deadline_s))s,
                        so the live S3-credentials test could not run.

                        `/s3credentials` redirects to urs.earthdata.nasa.gov, so an
                        Earthdata Login outage stops this test even when the DAAC itself
                        answers. Check whether the service is up before treating this as a
                        fault in EarthData.jl, and rerun the job once it is.

                        The underlying failure was:
                        $(sprint(showerror, err))
                        """)
                end
            end
        end
    end

    @testset "doctests" begin
        DocMeta.setdocmeta!(EarthData, :DocTestSetup, :(using EarthData); recursive=true)
        doctest(EarthData)
    end


end
