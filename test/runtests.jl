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

"""
    unreachable_host(err) -> Union{String,Nothing}

The host `err` failed to reach, or `nothing` if it is not a connection failure.

`/s3credentials` answers 307 to `urs.earthdata.nasa.gov`, so an EDL outage surfaces as a
connect timeout naming EDL rather than the DAAC. Distinguishing that from a genuine
failure is the difference between "NASA is down" and "this package is broken", and only the
libcurl message carries the host.
"""
function unreachable_host(err)
    EarthData.error_status(err) == 0 || return nothing
    msg = sprint(showerror, err)
    m = match(r"(?:Failed to connect to|Could not resolve host:?) ([\w.-]+)", msg)
    isnothing(m) || return m.captures[1]
    timed_out =
        occursin("Connection timed out", msg) || occursin("Timeout was reached", msg)
    timed_out || return nothing
    # A timeout with no host named is still a reachability failure; report the endpoint the
    # request was aimed at.
    m = match(r"while requesting https?://([\w.-]+)", msg)
    return isnothing(m) ? "the Earthdata endpoint" : m.captures[1]
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
                # A live call against NASA, so an outage must be reported as one rather
                # than as a package failure. `@test_broken` records it without failing the
                # suite: nothing here is under this repository's control.
                try
                    EarthData.create_aws_config(
                        deadline=time() + s3_credentials_deadline_s,
                    )
                    @test !isempty(get(ENV, "AWS_ACCESS_KEY_ID", ""))
                catch err
                    host = unreachable_host(err)
                    isnothing(host) && rethrow()
                    @warn """
                        Could not reach $(host) within $(Int(s3_credentials_deadline_s))s, \
                        so the live S3-credentials test did not run.

                        `/s3credentials` redirects to urs.earthdata.nasa.gov, so an \
                        Earthdata Login outage stops this test even though the DAAC itself \
                        answered. This is a NASA-side failure, not a fault in EarthData.jl \
                        — rerun the job once the service is back.
                        """ exception = (err, catch_backtrace())
                    @test_broken "S3 credentials require $(host), which is unreachable" ==
                                 ""
                end
            end
        end
    end

    @testset "doctests" begin
        DocMeta.setdocmeta!(EarthData, :DocTestSetup, :(using EarthData); recursive=true)
        doctest(EarthData)
    end


end
