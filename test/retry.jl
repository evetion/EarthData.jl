using HTTP
using Test

@testset "Transient/permanent split" begin
    # 5xx and the two "come back later" 4xx codes are the service saying nothing about the
    # request, so they are worth retrying.
    for status in (408, 429, 500, 502, 503, 504)
        r = HTTP.Response(status, [], "boom")
        @test_throws EarthData.TransientError EarthData.check_response(r, "test")
    end

    # A permanent status must fail on the first attempt: retrying a 403 EULA refusal loops
    # until the deadline and never succeeds.
    for status in (400, 401, 403, 404)
        r = HTTP.Response(status, [], "nope")
        @test_throws ArgumentError EarthData.check_response(r, "test")
    end

    @test EarthData.check_response(HTTP.Response(200, [], "ok"), "test") === nothing
    @test EarthData.check_response(HTTP.Response(303, [], ""), "test") === nothing

    # The messages have to name the fix, since neither status is self-explanatory to someone
    # who has a working token in hand.
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
    # A pathological header must not park a run for hours.
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
    # A transient failure is retried; `attempts` bounds it.
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

    # An already-passed deadline stops the retrying rather than sleeping into it.
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

    # The attempt cap must not be the limit that normally binds: at the maximum backoff it
    # has to outlast a maintenance window, leaving `deadline` in charge.
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

@testset "Verified download" begin
    folder = mktempdir()

    # The happy path: a full-size body lands at `path` and no `.part` survives.
    path = joinpath(folder, "full.h5")
    n = 4096
    EarthData.download_verified(
        "https://example.test/full.h5",
        path;
        bearer="fake-token",
        expected_bytes=n,
        verbose=false,
        downloader=(url, dest; headers) -> write(dest, zeros(UInt8, n)),
    )
    @test filesize(path) == n
    @test !isfile(path * ".part")

    # The bearer header has to reach the downloader, since that is the whole point of the
    # method existing alongside the netrc path.
    seen = Ref{Any}(nothing)
    EarthData.download_verified(
        "https://example.test/hdr.h5",
        joinpath(folder, "hdr.h5");
        bearer="fake-token",
        verbose=false,
        downloader=(url, dest; headers) -> (seen[] = headers; write(dest, "x")),
    )
    @test ("Authorization" => "Bearer fake-token") in seen[]

    # A truncated 200 is transient, not permanent: retrying is what recovers it. Left
    # unchecked, the short file would be opened later and GDAL's message for a corrupt HDF4
    # file names neither the download nor the size.
    attempts = Ref(0)
    short_path = joinpath(folder, "short.h5")
    EarthData.download_verified(
        "https://example.test/short.h5",
        short_path;
        bearer="fake-token",
        expected_bytes=n,
        verbose=false,
        downloader=(url, dest; headers) -> begin
            attempts[] += 1
            write(dest, zeros(UInt8, attempts[] == 1 ? 10 : n))
        end,
    )
    @test attempts[] == 2
    @test filesize(short_path) == n

    # A size within tolerance passes: `granule_size` can be a rounded megabyte figure, so an
    # exact comparison would reject good files.
    tol_path = joinpath(folder, "tol.h5")
    EarthData.download_verified(
        "https://example.test/tol.h5",
        tol_path;
        bearer="fake-token",
        expected_bytes=1000,
        verbose=false,
        downloader=(url, dest; headers) -> write(dest, zeros(UInt8, 995)),
    )
    @test filesize(tol_path) == 995

    # A failure leaves no partial file behind to be mistaken for a complete one.
    fail_path = joinpath(folder, "fail.h5")
    @test_throws ArgumentError EarthData.download_verified(
        "https://example.test/fail.h5",
        fail_path;
        bearer="fake-token",
        verbose=false,
        downloader=(url, dest; headers) -> begin
            write(dest, "partial")
            throw(ArgumentError("permanent"))
        end,
    )
    @test !isfile(fail_path)
    @test !isfile(fail_path * ".part")

    # An existing file is not re-downloaded.
    calls = Ref(0)
    EarthData.download_verified(
        "https://example.test/full.h5",
        path;
        bearer="fake-token",
        verbose=false,
        downloader=(url, dest; headers) -> (calls[] += 1),
    )
    @test calls[] == 0
end

@testset "Verified download of a granule" begin
    requests = []
    responses = [HTTP.Response(200, [], cmr_response(["G1"], "granule"))]
    granule = only(
        EarthData.request(
            "https://example.test/granules",
            Dict("short_name" => "TEST"),
            EarthData.Granules.UMM_G;
            requester=recording_requester(responses, requests),
        ),
    )

    folder = mktempdir()
    expected = EarthData.granule_size(granule)
    seen_url = Ref("")
    path = EarthData.download_verified(
        granule,
        folder;
        bearer="fake-token",
        verbose=false,
        downloader=(url, dest; headers) ->
            (seen_url[] = url; write(dest, zeros(UInt8, expected))),
    )

    # The `GET DATA` URL is the one fetched — not the S3 copy, and not the credentials
    # endpoint that an unfiltered HTTPS pick would return.
    @test seen_url[] == "https://example.test/G1.h5"
    @test path == joinpath(folder, "G1.h5")
    @test filesize(path) == expected
end
