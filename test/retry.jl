using Downloads
using HTTP
using Test

@testset "Temporary vs permanent" begin
    # 5xx and the two "come back later" 4xx codes say nothing about the request, so they are
    # worth retrying.
    for status in (408, 429, 500, 502, 503, 504)
        r = HTTP.Response(status, [], "boom")
        @test_throws EarthData.TransientError EarthData.check_response(r, "test")
    end

    # A permanent status must fail on the first attempt: retrying a 403 licence refusal loops
    # until the deadline and never succeeds.
    for status in (400, 401, 403, 404)
        r = HTTP.Response(status, [], "nope")
        @test_throws ArgumentError EarthData.check_response(r, "test")
    end

    @test EarthData.check_response(HTTP.Response(200, [], "ok"), "test") === nothing
    @test EarthData.check_response(HTTP.Response(303, [], ""), "test") === nothing

    # The messages have to name the fix, since neither status is self-explanatory to someone
    # holding a working token.
    e401 = try
        EarthData.check_response(HTTP.Response(401, [], "expired"), "download")
        nothing
    catch err
        err
    end
    @test occursin("EARTHDATA_TOKEN", e401.msg)
    @test occursin("60 days", e401.msg)

    e403 = try
        EarthData.check_response(HTTP.Response(403, [], "forbidden"), "download")
        nothing
    catch err
        err
    end
    @test occursin("licence", e403.msg)
    @test occursin("Retrying without doing so cannot help", e403.msg)

    @test EarthData.is_transient(EarthData.TransientError("c", 503, "d"))
    @test !EarthData.is_transient(ArgumentError("permanent"))
    @test !EarthData.is_transient(ErrorException("size mismatch"))
end

@testset "Status decides, not exception type" begin
    # `Downloads.download` throws RequestError for BOTH a transport fault and a plain HTTP
    # error status, so the type cannot be what classifies a failure. A transport fault
    # carries a libcurl code with status 0; an HTTP error carries CURLE_OK and the status.
    downloads_error(status, code=Downloads.Curl.CURLE_OK) = Downloads.RequestError(
        "https://example.test/f.h5",
        code,
        "",
        Downloads.Response("https", "https://example.test/f.h5", status, "", []),
    )

    # A 403 licence refusal must not be retried just because it arrived as a RequestError:
    # retrying it loops to the deadline and can never succeed.
    @test !EarthData.is_transient(downloads_error(403))
    @test !EarthData.is_transient(downloads_error(401))
    @test !EarthData.is_transient(downloads_error(404))
    @test !EarthData.is_transient(downloads_error(400))

    # A 5xx or "come back later" arriving the same way still is.
    for status in (408, 429, 500, 502, 503, 504)
        @test EarthData.is_transient(downloads_error(status))
    end

    # A genuine transport fault has status 0 and stays transient.
    @test EarthData.is_transient(
        downloads_error(0, Downloads.Curl.CURLE_COULDNT_RESOLVE_HOST),
    )

    # HTTP.jl's StatusError is split the same way.
    status_error(status) = HTTP.Exceptions.StatusError(
        status,
        "GET",
        "/f.h5",
        HTTP.Response(status, [], "body"),
    )
    @test !EarthData.is_transient(status_error(403))
    @test EarthData.is_transient(status_error(503))

    # `is_transient` and `check_response` must agree on every status, or a retry loop
    # disagrees with the message the user is shown.
    for status in (400, 401, 403, 404, 408, 429, 500, 502, 503, 504)
        threw_transient = try
            EarthData.check_response(HTTP.Response(status, [], "x"), "test")
            false
        catch err
            err isa EarthData.TransientError
        end
        @test threw_transient == EarthData.is_transient(downloads_error(status))
    end
end

@testset "Retry-After" begin
    @test EarthData.retry_after_seconds(HTTP.Response(429, [], "")) == 0.0
    @test EarthData.retry_after_seconds(HTTP.Response(429, ["Retry-After" => "12"], "")) ==
          12.0
    # A bad header must not park a run for hours.
    @test EarthData.retry_after_seconds(
        HTTP.Response(429, ["Retry-After" => "99999"], ""),
    ) == EarthData.retry_after_max
    # The HTTP-date form is not parsed; falling back to the backoff curve is safe.
    @test EarthData.retry_after_seconds(
        HTTP.Response(429, ["Retry-After" => "Wed, 21 Oct 2015 07:28:00 GMT"], ""),
    ) == 0.0

    r = HTTP.Response(503, ["Retry-After" => "7"], "down")
    err = try
        EarthData.check_response(r, "test")
        nothing
    catch e
        e
    end
    @test err.retry_after == 7.0

    # `Downloads.Response` is not an `HTTP.Message`, and it is the shape `/s3credentials`
    # fails with. Use the real struct rather than a NamedTuple stand-in, which supports
    # accessors the struct does not and so passes where the real type would not.
    downloads_response(status, headers) =
        Downloads.Response("https", "https://example.test", status, "", headers)

    @test EarthData.retry_after_seconds(
        downloads_response(503, ["Retry-After" => "7"]),
    ) == 7.0
    # Header names are case-insensitive, and a DAAC does send lowercase.
    @test EarthData.retry_after_seconds(
        downloads_response(503, ["retry-after" => "3"]),
    ) == 3.0
    # A response carrying no headers falls back to the backoff curve.
    @test EarthData.retry_after_seconds(
        downloads_response(503, Pair{String,String}[]),
    ) == 0.0

    # A 5xx `Downloads.Response` must reach `with_retries` as retryable, which is the whole
    # point: this is the shape `/s3credentials` fails with.
    err = try
        EarthData.check_response(downloads_response(503, ["Retry-After" => "5"]), "S3 credentials")
        nothing
    catch e
        e
    end
    @test err isa EarthData.TransientError
    @test EarthData.is_transient(err)
    @test err.retry_after == 5.0

    # NamedTuples must keep working — that is what the AWS extension passes.
    @test EarthData.retry_after_seconds((; status=503, headers=["Retry-After" => "7"])) ==
          7.0

    for status in (500, 503, 429, 408)
        err = try
            EarthData.check_response(
                (; status=status, body=codeunits("down"), headers=Pair{String,String}[]),
                "S3 credentials",
            )
            nothing
        catch e
            e
        end
        @test err isa EarthData.TransientError
        @test EarthData.is_transient(err)
    end

    # An HTML error page from an unauthenticated call is permanent, and says so rather than
    # surfacing as a JSON parse error.
    err = try
        EarthData.check_response(
            (;
                status=401,
                body=codeunits("<html>HTTP Basic: Access denied.</html>"),
                headers=Pair{String,String}[],
            ),
            "S3 credentials",
        )
        nothing
    catch e
        e
    end
    @test err isa ArgumentError
    @test !EarthData.is_transient(err)
    @test occursin("S3 credentials", err.msg)
end

@testset "retry_check" begin
    # HTTP.jl retries 403 by default. For a DAAC that is an unaccepted licence, so it must not
    # be retried — the one place the generic client's default is wrong for Earthdata.
    req = HTTP.Request("GET", "/")
    @test !EarthData.retry_check(nothing, nothing, req, HTTP.Response(403, [], ""), nothing)

    for status in (408, 429, 500, 502, 503, 504)
        @test EarthData.retry_check(
            nothing,
            nothing,
            req,
            HTTP.Response(status, [], ""),
            nothing,
        )
    end

    for status in (400, 401, 404)
        @test !EarthData.retry_check(
            nothing,
            nothing,
            req,
            HTTP.Response(status, [], ""),
            nothing,
        )
    end

    # No response at all (a connection fault) is HTTP.jl's own business, not ours.
    @test !EarthData.retry_check(nothing, nothing, req, nothing, nothing)
end

@testset "with_retries" begin
    # A temporary failure is retried; `attempts` bounds it.
    calls = Ref(0)
    result = EarthData.with_retries(; context="test", verbose=false) do
        calls[] += 1
        calls[] < 3 && throw(EarthData.TransientError("test", 503, "down", 0.0))
        return :ok
    end
    @test result == :ok
    @test calls[] == 3

    # A permanent error propagates on the first attempt, unchanged.
    calls[] = 0
    @test_throws ArgumentError EarthData.with_retries(; context="test", verbose=false) do
        calls[] += 1
        throw(ArgumentError("permanent"))
    end
    @test calls[] == 1

    # A deadline already passed stops the retrying rather than sleeping into it.
    calls[] = 0
    @test_throws EarthData.TransientError EarthData.with_retries(;
        context="test",
        verbose=false,
        deadline=time() - 1,
    ) do
        calls[] += 1
        throw(EarthData.TransientError("test", 503, "down", 0.0))
    end
    @test calls[] == 1

    @test sprint(showerror, EarthData.TransientError("ctx", 502, "gateway")) |>
          s -> occursin("502", s) && occursin("ctx", s)
end

@testset "earthdata_requester" begin
    # A CMR 503 should be retryable rather than collapsed into parse_cmr_error's generic
    # ErrorException.
    inner = (args...; kwargs...) -> HTTP.Response(503, [], "CMR is down")
    @test_throws EarthData.TransientError EarthData.earthdata_requester(inner)(
        "POST",
        "https://example.test",
        [],
    )

    # A permanent status is handed back untouched, so `parse_cmr_error` still reports CMR's
    # own `errors` array.
    body = JSON3.write(Dict("errors" => ["Parameter [nope] was not recognized."]))
    permanent = (args...; kwargs...) -> HTTP.Response(400, [], body)
    r = EarthData.earthdata_requester(permanent)("POST", "https://example.test", [])
    @test r.status == 400

    requests = []
    responses = [HTTP.Response(200, [], cmr_response(["G1"], "granule"))]
    gg = EarthData.request(
        "https://example.test/granules",
        Dict("short_name" => "TEST"),
        EarthData.Granules.UMM_G;
        requester=EarthData.earthdata_requester(
            recording_requester(responses, requests),
        ),
    )
    @test length(gg) == 1
    @test length(requests) == 1
end
