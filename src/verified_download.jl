# Tolerance on a CMR-reported size, as a fraction. `granule_size` can be a rounded megabyte
# figure, so it cannot be compared exactly; wide enough to absorb that rounding, narrow
# enough to catch a cut-off transfer.
const size_tolerance = 0.01

"""
    download_verified(url, path; bearer=token(), expected_bytes=0, verbose=true,
                      deadline=Inf) -> path

Download `url` to `path` with an Earthdata Login bearer token, retrying temporary failures.

Complements the `aria2c` batch path, which resumes an interrupted file but does not check
whether the result is complete. Two things this adds over a plain `download`:

- It writes `path * ".part"` and moves it into place only on success, so an interrupted
  transfer never leaves behind a file that looks finished.
- When `expected_bytes > 0` (pass [`granule_size`](@ref)) the final size is checked against
  it within `size_tolerance`. A short file is treated as a temporary failure and downloaded
  again, because a truncated HDF or NetCDF granule surfaces much later, as a reader error
  naming neither the download nor the size.

An existing `path` is returned untouched.

!!! note "The bearer header survives the redirect"
    LP DAAC answers a bearer-authenticated GET with a 303 to CloudFront, and
    `Downloads.download` follows it and returns the full body — measured, with and without
    the header forwarded. The presigned-URL/`Authorization` conflict that affects some S3
    endpoints does not arise here.
"""
function download_verified(
    url::AbstractString,
    path::AbstractString;
    bearer=token(),
    expected_bytes::Integer=0,
    verbose::Bool=true,
    deadline::Float64=Inf,
    downloader=Downloads.download,
)
    isfile(path) && return path
    mkpath(dirname(abspath(path)))
    tmp = path * ".part"
    headers = auth_headers(; bearer)
    context = "download $(basename(path))"

    try
        with_retries(; context, verbose, deadline) do
            isfile(tmp) && rm(tmp; force=true)
            downloader(url, tmp; headers)
            n = filesize(tmp)
            if expected_bytes > 0 && n < expected_bytes * (1 - size_tolerance)
                # Retryable: a short body is a cut-off transfer, not a bad request.
                throw(
                    TransientError(
                        context,
                        0,
                        "Got $(n) bytes, expected ≈$(expected_bytes) — transfer was truncated.",
                    ),
                )
            end
            return nothing
        end
        mv(tmp, path; force=true)
    catch
        isfile(tmp) && rm(tmp; force=true)
        rethrow()
    end
    return path
end

"""
    download_verified(granule, folder="."; kwargs...) -> path

Download a granule's `"GET DATA"` file into `folder`, checking its size against
[`granule_size`](@ref).
"""
function download_verified(granule::AbstractJSON, folder::AbstractString="."; kwargs...)
    url = download_url(granule; type="GET DATA")
    isnothing(url) &&
        error("Granule has no \"GET DATA\" URL to download: $(urls(granule))")
    path = joinpath(folder, url_filename(url))
    expected = something(granule_size(granule), 0)
    return download_verified(url, path; expected_bytes=expected, kwargs...)
end
