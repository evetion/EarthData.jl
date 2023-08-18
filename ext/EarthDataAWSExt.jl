module EarthDataAWSExt

using EarthData
using AWSS3
using JSON3
using Dates

function get_s3_credentials(daac="nsidc")
    body = sprint() do output
        return EarthData._request(
            "https://data.$daac.earthdatacloud.nasa.gov/s3credentials";
            output=output
        )
    end
    body = JSON3.read(body)
    AWSS3.AWSCredentials(
        body.accessKeyId,
        body.secretAccessKey,
        body.sessionToken,
        expiry=DateTime(body.expiration, dateformat"y-m-d H:M:S+z"),
    )
end

function set_env!(creds::AWSS3.AWSCredentials, env=ENV)
    env["AWS_ACCESS_KEY_ID"] = creds.access_key_id
    env["AWS_SECRET_ACCESS_KEY"] = creds.secret_key
    env["AWS_SESSION_TOKEN"] = creds.token
    env["AWS_SESSION_EXPIRES"] = creds.expiry
end

function create_aws_config(daac="nsidc", region="us-west-2")
    expiry = DateTime(get(ENV, "AWS_SESSION_EXPIRES", typemin(DateTime)))
    if expiry < Dates.now(UTC)
        # If credentials are expired or unset, get new ones
        creds = get_s3_credentials(daac)
        set_env!(creds)
    else
        # Otherwise, get them from the environment
        creds = AWSS3.AWSCredentials(
            get(ENV, "AWS_ACCESS_KEY_ID", ""),
            get(ENV, "AWS_SECRET_ACCESS_KEY", ""),
            get(ENV, "AWS_SESSION_TOKEN", ""),
            expiry=DateTime(get(ENV, "AWS_SESSION_EXPIRES", typemax(DateTime))),
        )
    end

    AWSS3.global_aws_config(; creds, region)
end

function s3download(url, fn, config=create_aws_config())
    bucket, path = split(last(split(url, "//")), "/"; limit=2)
    AWSS3.s3_get_file(config, bucket, path, fn)
end

end # module
