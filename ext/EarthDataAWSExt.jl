module EarthDataAWSExt

using EarthData
using AWSS3
using JSON3
using Dates
using TimeZones
import Downloads

function _fetch_s3_credentials(daac)
    url = "https://data.$daac.earthdatacloud.nasa.gov/s3credentials"
    # Declared outside so the closure's response survives `sprint`, which returns the body.
    response = nothing
    body = sprint() do output
        response = Downloads.request(url; output=output)
    end

    # `Downloads.request` returns a `Response` for an HTTP error status rather than throwing
    # (a transport fault does throw, as `RequestError`, and propagates), so an error status
    # has to be read off the response.
    #
    # It will not always be one: without credentials, curl follows the redirect to the EDL
    # login form and the *login page* answers 200, so an unauthenticated call arrives here as
    # a successful HTML response. That case is caught by the JSON read below, which is why it
    # names the URL rather than letting a bare parse error surface.
    EarthData.check_response(
        (; status=response.status, body=codeunits(body), headers=response.headers),
        "S3 credentials",
    )

    credentials = try
        JSON3.read(body)
    catch
        throw(
            ArgumentError(
                """
                Could not read the S3 credentials response as JSON ($url).

                $(EarthData.body_excerpt((; body=codeunits(body))))
                """,
            ),
        )
    end

    AWSS3.AWSCredentials(
        credentials.accessKeyId,
        credentials.secretAccessKey,
        credentials.sessionToken,
        expiry=DateTime(credentials.expiration, dateformat"y-m-d H:M:S+z"),
    )
end

"""
    get_s3_credentials(daac="nsidc") -> AWSS3.AWSCredentials

Fetch temporary in-region S3 credentials from a DAAC's `/s3credentials` endpoint.

Requires Earthdata Login credentials (see `netrc!`). Retries while the endpoint fails
temporarily; a 401/403 is permanent and raises immediately.
"""
function EarthData.get_s3_credentials(daac="nsidc")
    EarthData.with_retries(context="S3 credentials") do
        _fetch_s3_credentials(daac)
    end
end

function set_env!(creds::AWSS3.AWSCredentials, env=ENV)
    env["AWS_ACCESS_KEY_ID"] = creds.access_key_id
    env["AWS_SECRET_ACCESS_KEY"] = creds.secret_key
    env["AWS_SESSION_TOKEN"] = creds.token
    # `ENV` holds strings; assigning the `DateTime` itself raises a `MethodError`.
    env["AWS_SESSION_EXPIRES"] = string(creds.expiry)
end

function EarthData.create_aws_config(daac="nsidc", region="us-west-2")
    expiration = DateTime(get(ENV, "AWS_SESSION_EXPIRES", typemin(DateTime)))
    if expiration < Dates.now(UTC)
        # If credentials are expired or unset, get new ones
        creds = EarthData.get_s3_credentials(daac)
        set_env!(creds)
    else
        # Otherwise, get them from the environment
        creds = AWSS3.AWSCredentials(
            get(ENV, "AWS_ACCESS_KEY_ID", ""),
            get(ENV, "AWS_SECRET_ACCESS_KEY", ""),
            get(ENV, "AWS_SESSION_TOKEN", ""),
            expiry=expiration,
        )
    end

    AWSS3.global_aws_config(; creds, region)
end

function EarthData.s3download(url, fn, config=EarthData.create_aws_config())
    bucket, path = split(last(split(url, "//")), "/"; limit=2)
    AWSS3.s3_get_file(config, bucket, path, fn)
end

end # module
