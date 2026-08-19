using HTTP
using JSON3

@testset "Token resolution" begin
    withenv("EARTHDATA_TOKEN" => "  tok-from-env  ") do
        # The environment variable wins, and is stripped.
        @test EarthData.token() == "tok-from-env"
    end

    mktempdir() do dir
        # An empty variable is treated as absent, not as an empty token — otherwise a shell
        # that exports it unset produces a 401 instead of a setup message.
        withenv("EARTHDATA_TOKEN" => "", "HOME" => dir) do
            @test_throws ErrorException EarthData.token()
        end

        write(joinpath(dir, ".edl_token"), "# my token\n\ntok-from-file\n")
        withenv("EARTHDATA_TOKEN" => nothing, "HOME" => dir) do
            @test EarthData.token() == "tok-from-file"
        end
    end

    mktempdir() do dir
        withenv("EARTHDATA_TOKEN" => nothing, "HOME" => dir) do
            msg = try
                EarthData.token()
                ""
            catch err
                sprint(showerror, err)
            end
            # The message must name the token page and the two-token limit: requesting a
            # third token is the most common first-run failure.
            @test occursin(EarthData.token_page, msg)
            @test occursin("two", msg)
            @test occursin("EARTHDATA_TOKEN", msg)
        end
    end

    @test EarthData.auth_headers(bearer="abc") == ["Authorization" => "Bearer abc"]
end

@testset ".netrc credentials" begin
    mktempdir() do dir
        path = joinpath(dir, "netrc")
        write(
            path,
            """
            machine example.com login wrong password wrong
            machine urs.earthdata.nasa.gov
                login someone
                password s3cret
            """,
        )
        @test EarthData.netrc_credentials("urs.earthdata.nasa.gov"; path) ==
              ("someone", "s3cret")
        # A machine with no credentials is an error, not a silent fall-through to the
        # wrong stanza.
        @test_throws ErrorException EarthData.netrc_credentials("nasa.example"; path)
        @test_throws ErrorException EarthData.netrc_credentials(
            "urs.earthdata.nasa.gov";
            path=joinpath(dir, "absent"),
        )

        withenv("NETRC" => path) do
            @test EarthData.netrc_credentials() == ("someone", "s3cret")
        end
    end
end

@testset "Token from .netrc" begin
    mktempdir() do dir
        path = joinpath(dir, "netrc")
        write(path, "machine urs.earthdata.nasa.gov login someone password s3cret\n")

        requests = []
        function requester(method, url, headers; kwargs...)
            push!(requests, (; method=String(method), url=String(url), headers))
            return HTTP.Response(
                200,
                Pair{String,String}[];
                body=JSON3.write([Dict("access_token" => "tok-from-edl")]),
            )
        end

        withenv("NETRC" => path) do
            @test EarthData.token_from_netrc(; requester) == "tok-from-edl"
        end
        # `create=false` must LIST tokens (GET /tokens), never create one: an account may
        # hold only two, and a third request is refused.
        @test only(requests).method == "GET"
        @test endswith(only(requests).url, "/tokens")
        @test any(
            p -> String(p[1]) == "Authorization" && startswith(String(p[2]), "Basic "),
            only(requests).headers,
        )

        empty!(requests)
        creating(args...; kwargs...) = requester(args...; kwargs...)
        withenv("NETRC" => path) do
            EarthData.token_from_netrc(; create=true, requester=creating)
        end
        @test only(requests).method == "POST"
        @test endswith(only(requests).url, "/token")

        # An empty token list is an actionable error, not an empty string handed onward.
        empty_list(args...; kwargs...) =
            HTTP.Response(200, Pair{String,String}[]; body="[]")
        withenv("NETRC" => path) do
            @test_throws ErrorException EarthData.token_from_netrc(; requester=empty_list)
        end

        refused(args...; kwargs...) =
            HTTP.Response(403, Pair{String,String}[]; body="max tokens")
        withenv("NETRC" => path) do
            msg = try
                EarthData.token_from_netrc(; create=true, requester=refused)
                ""
            catch err
                sprint(showerror, err)
            end
            @test occursin("403", msg)
            @test occursin("two-token limit", msg)
        end
    end
end
