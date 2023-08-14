using AWSS3
using JSON3
using HTTP

function get_s3_credentials(daac="nsidc")
    body = sprint() do output
        return _request(
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
