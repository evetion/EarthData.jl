using HTTP
using JSON3
import Base64

# `homedir()` reads HOME on Unix but USERPROFILE on Windows (libuv's uv_os_homedir), so
# redirecting only HOME leaves the real home directory in play on Windows.
withhome(f, dir, env::Pair...) = withenv(f, "HOME" => dir, "USERPROFILE" => dir, env...)

@testset "Token resolution" begin
    withenv("EARTHDATA_TOKEN" => "  tok-from-env  ") do
        # The environment variable wins, and is stripped.
        @test EarthData.token() == "tok-from-env"
    end

    mktempdir() do dir
        # An empty variable is treated as absent, not as an empty token — otherwise a shell
        # that exports it unset produces a 401 instead of a setup message.
        withhome(dir, "EARTHDATA_TOKEN" => "") do
            @test_throws ErrorException EarthData.token()
        end

        write(joinpath(dir, ".edl_token"), "# my token\n\ntok-from-file\n")
        withhome(dir, "EARTHDATA_TOKEN" => nothing) do
            @test EarthData.token() == "tok-from-file"
        end
    end

    mktempdir() do dir
        withhome(dir, "EARTHDATA_TOKEN" => nothing) do
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

    mktempdir() do dir
        path = joinpath(dir, "netrc")
        # A commented-out stanza is not a credential. Reading one would send a password the
        # user disabled on purpose.
        write(
            path,
            """
            # machine urs.earthdata.nasa.gov login old password old
            machine urs.earthdata.nasa.gov login someone password s3cret
            """,
        )
        @test EarthData.netrc_credentials("urs.earthdata.nasa.gov"; path) ==
              ("someone", "s3cret")

        # `default` applies to machines with no stanza of their own, so it must not hand
        # over another machine's credentials.
        write(
            path,
            """
            machine example.com login other password otherpw
            default login anyone password anypw
            """,
        )
        @test EarthData.netrc_credentials("nasa.example"; path) == ("anyone", "anypw")
        @test EarthData.netrc_credentials("example.com"; path) == ("other", "otherpw")
    end
end

@testset "Writing .netrc" begin
    mktempdir() do dir
        path = joinpath(dir, "netrc")

        @test EarthData.netrc!("someone", "s3cret"; path) == path
        @test EarthData.netrc_credentials("urs.earthdata.nasa.gov"; path) ==
              ("someone", "s3cret")
        # A plaintext password must not be world-readable. `chmod` restricts the file on
        # Windows as well, by rewriting its ACL, but `stat` there derives the mode from the
        # read-only attribute alone and never reads the ACL — so any writable file reports
        # 0o666 and the mode is only observable where it maps to POSIX bits.
        Sys.iswindows() || @test filemode(path) & 0o777 == 0o600

        # Calling again with a corrected password has to take effect. curl reads the FIRST
        # stanza matching a machine, so appending a second one changes nothing.
        EarthData.netrc!("someone", "corrected"; path)
        @test EarthData.netrc_credentials("urs.earthdata.nasa.gov"; path) ==
              ("someone", "corrected")
        @test count(contains("urs.earthdata.nasa.gov"), readlines(path)) == 1

        # Other machines and comments survive the rewrite.
        write(
            path,
            """
            # keep me
            machine example.com login other password otherpw
            machine urs.earthdata.nasa.gov login stale password stale
            """,
        )
        EarthData.netrc!("someone", "fresh"; path)
        lines = readlines(path)
        @test "# keep me" in lines
        @test EarthData.netrc_credentials("example.com"; path) == ("other", "otherpw")
        @test EarthData.netrc_credentials("urs.earthdata.nasa.gov"; path) ==
              ("someone", "fresh")

        # A multi-line stanza is removed in full, so no orphaned login/password is left to
        # be read as the next machine's.
        write(
            path,
            """
            machine urs.earthdata.nasa.gov
                login stale
                password stale
            machine example.com login other password otherpw
            """,
        )
        EarthData.netrc!("someone", "fresh"; path)
        @test EarthData.netrc_credentials("urs.earthdata.nasa.gov"; path) ==
              ("someone", "fresh")
        @test EarthData.netrc_credentials("example.com"; path) == ("other", "otherpw")

        # Writing to a machine that is not present adds it rather than replacing anything.
        EarthData.netrc!("u", "p"; machine="uat.urs.earthdata.nasa.gov", path)
        @test EarthData.netrc_credentials("uat.urs.earthdata.nasa.gov"; path) == ("u", "p")
        @test EarthData.netrc_credentials("urs.earthdata.nasa.gov"; path) ==
              ("someone", "fresh")

        # Rewriting one line that holds two machines would corrupt the other, so it raises
        # rather than guessing.
        write(path, "machine urs.earthdata.nasa.gov login a password b machine x login c\n")
        @test_throws "cannot be replaced without rewriting the line" EarthData.netrc!(
            "someone",
            "s3cret";
            path,
        )
    end

    # `.netrc` separates tokens on whitespace, so a credential containing any cannot be
    # written: the file would parse as different values than were passed.
    mktempdir() do dir
        path = joinpath(dir, "netrc")
        @test_throws "contains whitespace" EarthData.netrc!("some one", "s3cret"; path)
        @test_throws "contains whitespace" EarthData.netrc!("someone", "s3 cret"; path)
        @test_throws "is empty" EarthData.netrc!("", "s3cret"; path)
        @test !isfile(path)
    end
end

@testset ".netrc path resolution" begin
    mktempdir() do dir
        withhome(dir, "NETRC" => nothing) do
            @test EarthData.netrc_path() ==
                  joinpath(dir, Sys.iswindows() ? "_netrc" : ".netrc")
        end
        # Reads and writes must agree on the file, and both must agree with what the
        # downloaders are pointed at.
        withhome(dir, "NETRC" => joinpath(dir, "elsewhere")) do
            @test EarthData.netrc_path() == joinpath(dir, "elsewhere")
            @test EarthData.netrc!("someone", "s3cret") == joinpath(dir, "elsewhere")
            @test EarthData.netrc_credentials() == ("someone", "s3cret")
        end
    end
end

@testset "Downloads use the same .netrc" begin
    mktempdir() do dir
        elsewhere = joinpath(dir, "elsewhere")
        withhome(dir, "NETRC" => elsewhere) do
            EarthData.netrc!("someone", "s3cret"; machine="127.0.0.1")

            # libcurl resolves `.netrc` from the home directory and ignores `NETRC`, so
            # `CURLOPT_NETRC_FILE` is what keeps a download on the file
            # `netrc_credentials` reads. The assertion is on what reaches the wire: a
            # local server records the header libcurl chose to send.
            seen = String[]
            server = HTTP.serve!("127.0.0.1", 8134) do request
                push!(seen, something(HTTP.header(request, "Authorization", nothing), ""))
                HTTP.Response(200, "ok")
            end
            try
                EarthData.download("http://127.0.0.1:8134/f", joinpath(dir, "f"))
            finally
                close(server)
            end
            @test only(seen) ==
                  "Basic " * Base64.base64encode("someone:s3cret")

            # aria2c likewise reads `$HOME/.netrc` only.
            commands = Cmd[]
            EarthData.download(
                ["https://example.invalid/x"],
                joinpath(dir, "out");
                runner=cmd -> push!(commands, cmd),
            )
            @test occursin("--netrc-path=$(elsewhere)", string(only(commands)))
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
