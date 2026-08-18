using HTTP
using Test

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

    # The bearer header has to reach the downloader, since that is the point of this method
    # existing alongside the netrc path.
    seen = Ref{Any}(nothing)
    EarthData.download_verified(
        "https://example.test/hdr.h5",
        joinpath(folder, "hdr.h5");
        bearer="fake-token",
        verbose=false,
        downloader=(url, dest; headers) -> (seen[] = headers; write(dest, "x")),
    )
    @test ("Authorization" => "Bearer fake-token") in seen[]

    # A truncated 200 is temporary, not permanent: retrying is what recovers it. Left
    # unchecked, the short file would be opened later, and a reader's error for a corrupt
    # HDF4 file names neither the download nor the size.
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

    # An existing file is not downloaded again.
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
    # endpoint an unfiltered HTTPS pick would return.
    @test seen_url[] == "https://example.test/G1.h5"
    @test path == joinpath(folder, "G1.h5")
    @test filesize(path) == expected
end
