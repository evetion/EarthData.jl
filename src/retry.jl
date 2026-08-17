"""
Retry policy for Earthdata and CMR requests.

The transient/permanent split matters in both directions, and getting it wrong is expensive
either way: retrying a permanent error produces an endless request loop, while failing fast
on a service hiccup discards however much work a run had already done.

Transient — the service said nothing about the request:

- **5xx**, plus **408** and **429** (a legal request, and the service asking us to come
  back later).
- Connection-level faults: DNS, connect, timeout, reset, truncated body.

Permanent — retrying cannot help:

- **401** — the bearer token is missing, malformed or expired (they last 60 days).
- **403** — the token is valid but the account has not accepted the collection's licence or
  approved the DAAC application. No amount of waiting fixes this.
- **404** — the granule is not there.
- **400** — the query is wrong.
"""

# The attempt cap must not be the binding limit; a caller's `deadline` should be. A download
# is minutes of work, so a maintenance window is worth waiting out rather than discarding.
const retry_base = 2.0
const retry_max_backoff = 60.0
const retry_attempts = 60

const transient_statuses = (408, 429, 500, 502, 503, 504)

# Cap on an honoured `Retry-After`, so a pathological header cannot park a run for hours.
const retry_after_max = 300.0

"""
    TransientError(context, status, detail, retry_after=0.0)

An Earthdata or CMR response that says nothing about the request: a 5xx, or a 408/429. See
the module docstring for why this is distinguished from 401/403/404.
"""
struct TransientError <: Exception
    context::String
    status::Int
    detail::String
    retry_after::Float64   # server-requested wait in seconds; 0.0 when unspecified
end

TransientError(context, status, detail) = TransientError(context, status, detail, 0.0)

function Base.showerror(io::IO, e::TransientError)
    print(
        io,
        """
        Earthdata server error ($(e.context), HTTP $(e.status)).

        $(e.detail)

        This is a service-side fault rather than a problem with the request, and is
        normally transient.
        """,
    )
end

"""
    retry_after_seconds(response) -> Float64

Seconds the server asked us to wait, from `Retry-After`, or `0.0` when the header is absent
or unparseable. Only the delta-seconds form is honoured; clamped to `retry_after_max`.
"""
function retry_after_seconds(response)
    raw = HTTP.header(response, "Retry-After", "")
    isempty(strip(raw)) && return 0.0
    seconds = tryparse(Float64, strip(raw))
    isnothing(seconds) && return 0.0
    return clamp(seconds, 0.0, retry_after_max)
end

"""
    is_transient(err) -> Bool

Whether `err` is worth retrying. Deliberately narrow: a [`TransientError`](@ref) or a
connection-level failure. `ArgumentError` (a permanent status, a bad query) and plain
`ErrorException` (a size mismatch, a missing link) are not transient.
"""
is_transient(err) =
    err isa TransientError ||
    err isa HTTP.Exceptions.ConnectError ||
    err isa HTTP.Exceptions.TimeoutError ||
    err isa HTTP.Exceptions.RequestError ||
    err isa Downloads.RequestError ||
    err isa Base.IOError ||
    err isa EOFError

# Response bodies can be a full HTML error page; keep the message readable.
function body_excerpt(r; limit::Integer=800)
    body = try
        String(r.body)
    catch
        ""
    end
    s = strip(body)
    isempty(s) && return "(empty response body)"
    return length(s) <= limit ? s : string(first(s, limit), "\n… (truncated)")
end

"""
    check_response(r, context)

Throw for an error response: [`TransientError`](@ref) for a retryable status, an
`ArgumentError` carrying actionable advice for a permanent one. Returns `nothing` on
success.
"""
function check_response(r, context::AbstractString)
    r.status < 400 && return nothing
    detail = body_excerpt(r)
    if r.status in transient_statuses || r.status >= 500
        throw(TransientError(context, r.status, detail, retry_after_seconds(r)))
    elseif r.status == 401
        throw(
            ArgumentError(
                """
                Earthdata Login rejected the token ($(context), HTTP 401).

                $(detail)

                Tokens expire after 60 days. Check EARTHDATA_TOKEN, or list/create one at
                $(token_page).
                """,
            ),
        )
    elseif r.status == 403
        throw(
            ArgumentError(
                """
                Earthdata accepted the token but refused the request ($(context), HTTP 403).

                $(detail)

                This is almost always an unaccepted end-user licence or an unapproved
                application rather than a bad token — log in at
                https://urs.earthdata.nasa.gov/ and approve the DAAC application, then
                retry. Retrying without doing so cannot help.
                """,
            ),
        )
    else
        throw(
            ArgumentError(
                """
                Earthdata request failed ($(context), HTTP $(r.status)).

                $(detail)
                """,
            ),
        )
    end
end

"""
    with_retries(f; context, attempts=retry_attempts, verbose=true, deadline=Inf) -> f()

Call `f`, retrying while it fails transiently (see [`is_transient`](@ref)) with exponential
backoff from `retry_base` to `retry_max_backoff`. Non-transient errors propagate on the
first attempt, unchanged, and the final failure is rethrown rather than wrapped so the
message the user sees is the service's own.

`deadline` is an absolute `time()` value bounding the retrying, and it — not `attempts` —
is what should normally bind. A server-supplied `Retry-After` overrides the backoff curve
upward; the service knows better than we do.
"""
function with_retries(
    f;
    context::AbstractString,
    attempts::Integer=retry_attempts,
    verbose::Bool=true,
    deadline::Float64=Inf,
)
    attempt = 0
    while true
        attempt += 1
        try
            return f()
        catch err
            (is_transient(err) && attempt < attempts) || rethrow()
            backoff = min(retry_base * 2.0^(attempt - 1), retry_max_backoff)
            requested = err isa TransientError ? err.retry_after : 0.0
            requested > 0 && (backoff = max(backoff, requested))
            time() + backoff >= deadline && rethrow()
            verbose && @warn "Transient Earthdata failure; retrying" context attempt backoff_s =
                round(backoff; digits=1) error = sprint(showerror, err)
            sleep(backoff)
        end
    end
end

"""
    classifying_requester(inner=HTTP.request, context="CMR search")

Wrap a `requester` (as accepted by [`request`](@ref), [`granules`](@ref) and
[`collections`](@ref)) so a transient status throws [`TransientError`](@ref) instead of
being turned into a plain `ErrorException` by `parse_cmr_error`.

Only transient statuses are intercepted; permanent ones are handed back untouched so
`parse_cmr_error`'s reading of CMR's `errors` array is what the caller sees.

```julia
granules(
    short_name="MCD43A3",
    version="061",
    requester=classifying_requester(),
)
```
"""
function classifying_requester(inner=HTTP.request, context::AbstractString="CMR search")
    return function (args...; kwargs...)
        r = inner(args...; kwargs...)
        if r.status in transient_statuses || r.status >= 500
            throw(TransientError(context, r.status, body_excerpt(r), retry_after_seconds(r)))
        end
        return r
    end
end

# Tolerance on a CMR-reported size, as a fraction. `granule_size` can be a rounded megabyte
# figure, so it cannot be compared exactly; wide enough to absorb the rounding and narrow
# enough to catch a truncated transfer.
const size_tolerance = 0.01

"""
    download_verified(url, path; bearer=token(), expected_bytes=0, verbose=true,
                      deadline=Inf) -> path

Download `url` to `path` with an Earthdata Login bearer token, retrying transient failures.

Writes to `path * ".part"` and moves it into place on success, so an interrupted transfer
never leaves a plausible-looking truncated file behind. When `expected_bytes > 0` (pass
[`granule_size`](@ref)) the final size is checked against it within `size_tolerance`; a
short file is treated as a transient failure and re-downloaded, because a truncated HDF or
NetCDF granule fails much later and far less legibly than a failed download does.

An existing `path` is returned untouched.

!!! note "The bearer header survives the redirect"
    LP DAAC answers a bearer-authenticated GET with a 303 to CloudFront, and
    `Downloads.download` follows it and returns the full body — measured, with and without
    the header forwarded. The presigned-URL/`Authorization` conflict that affects some S3
    endpoints does not arise on this path.
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

Download a granule's `"GET DATA"` file into `folder`, verifying its size against
[`granule_size`](@ref).
"""
function download_verified(
    granule::AbstractJSON,
    folder::AbstractString=".";
    kwargs...,
)
    url = download_url(granule; type="GET DATA")
    isnothing(url) &&
        error("Granule has no \"GET DATA\" URL to download: $(urls(granule))")
    path = joinpath(folder, url_filename(url))
    expected = something(granule_size(granule), 0)
    return download_verified(url, path; expected_bytes=expected, kwargs...)
end
