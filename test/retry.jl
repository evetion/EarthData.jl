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

    # The attempt cap should not be what normally stops a run: at the maximum backoff it has
    # to outlast a maintenance window, leaving `deadline` in charge.
    @test EarthData.retry_attempts * EarthData.retry_max_backoff >= 3600

    @test sprint(showerror, EarthData.TransientError("ctx", 502, "gateway")) |>
          s -> occursin("502", s) && occursin("ctx", s)
end

@testset "classifying_requester" begin
    # A CMR 503 should be retryable rather than collapsed into parse_cmr_error's generic
    # ErrorException.
    inner = (args...; kwargs...) -> HTTP.Response(503, [], "CMR is down")
    @test_throws EarthData.TransientError EarthData.classifying_requester(inner)(
        "POST",
        "https://example.test",
        [],
    )

    # A permanent status is handed back untouched, so `parse_cmr_error` still reports CMR's
    # own `errors` array.
    body = JSON3.write(Dict("errors" => ["Parameter [nope] was not recognized."]))
    permanent = (args...; kwargs...) -> HTTP.Response(400, [], body)
    r = EarthData.classifying_requester(permanent)("POST", "https://example.test", [])
    @test r.status == 400

    requests = []
    responses = [HTTP.Response(200, [], cmr_response(["G1"], "granule"))]
    gg = EarthData.request(
        "https://example.test/granules",
        Dict("short_name" => "TEST"),
        EarthData.Granules.UMM_G;
        requester=EarthData.classifying_requester(
            recording_requester(responses, requests),
        ),
    )
    @test length(gg) == 1
    @test length(requests) == 1
end
