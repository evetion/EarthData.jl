"""
Telling a temporary failure apart from a permanent one.

Both directions cost real work if you get them wrong. Giving up on a brief server hiccup
throws away everything a long run had done. Retrying an error that can never succeed loops
until the deadline.

Temporary — the service said nothing about the request:

- **5xx**, plus **408** and **429** (the request was fine; come back later).
- Connection faults: DNS, connect, timeout, reset, truncated body.

Permanent — retrying cannot help:

- **400** — the query is wrong.
- **401** — the token is missing, malformed or expired (they last 60 days).
- **403** — the token works, but the account has not accepted the collection's licence or
  approved the DAAC application.
- **404** — it is not there.

The status decides, not the exception type: `Downloads.RequestError` is thrown both for a
transport fault and for any HTTP error status, so a 403 and a 503 reach us as the same type.
See [`error_status`](@ref).
"""

const retry_base = 2.0
const retry_max_backoff = 60.0

# The attempt cap should not be what stops a run; a caller's `deadline` should. A download is
# minutes of work, so a maintenance window is worth waiting out rather than discarding.
const retry_attempts = 60

const transient_statuses = (408, 429, 500, 502, 503, 504)

# Cap on an honoured `Retry-After`, so a bad header cannot park a run for hours.
const retry_after_max = 300.0

const token_page_url = "https://urs.earthdata.nasa.gov/users/tokens"

"""
    TransientError(context, status, detail, retry_after=0.0)

A response that says nothing about the request: a 5xx, a 408 or a 429. Worth retrying,
unlike a 401/403/404.
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

        This is a fault on the service side rather than a problem with the request, and is
        usually temporary.
        """,
    )
end

# `HTTP.header` only accepts an `HTTP.Messages.Message`. A `Downloads.Response` carries its
# headers as plain pairs, so read those directly rather than by type.
retry_after_header(response::HTTP.Messages.Message) =
    HTTP.header(response, "Retry-After", "")

# `Downloads.Response` is a plain struct: `get(f, ::Downloads.Response, ::Symbol)` does not
# exist, so reach for the field rather than an index. Getting this wrong is what turned a
# 503 into a `MethodError`, which `is_transient` reads as permanent.
headers_of(response) = hasproperty(response, :headers) ? response.headers : ()

function retry_after_header(response)
    for (name, value) in headers_of(response)
        lowercase(String(name)) == "retry-after" && return String(value)
    end
    return ""
end

"""
    retry_after_seconds(response) -> Float64

Seconds the server asked us to wait, from `Retry-After`, or `0.0` when the header is absent
or unparseable. Only the delta-seconds form is read; clamped to `retry_after_max`.

Accepts an `HTTP.Response` or anything else carrying a `headers` collection of pairs, such
as a `Downloads.Response`. A response without headers at all reads as `0.0`.
"""
function retry_after_seconds(response)
    raw = retry_after_header(response)
    isempty(strip(raw)) && return 0.0
    seconds = tryparse(Float64, strip(raw))
    isnothing(seconds) && return 0.0
    return clamp(seconds, 0.0, retry_after_max)
end

"""
    error_status(err) -> Int

The HTTP status `err` carries, or `0` when it carries none.

The exception type alone does not say whether a failure was temporary.
`Downloads.RequestError` is thrown for both kinds: a transport fault carries a libcurl
`code` with `response.status == 0`, while a plain HTTP error status carries
`code == CURLE_OK` and the status in `response.status`. A 503 worth retrying and a 403 that
never will be are the same type, so the status has to be read rather than inferred.
"""
error_status(err::Downloads.RequestError) = err.response.status
error_status(err::HTTP.Exceptions.StatusError) = err.status
error_status(err) = 0

"""
    is_transient_status(status) -> Bool

Whether an HTTP status is worth retrying: a 5xx, a 408 or a 429.
"""
is_transient_status(status::Integer) = status in transient_statuses || status >= 500

"""
    is_transient(err) -> Bool

Whether `err` is worth retrying: a [`TransientError`](@ref) or a connection failure.
Deliberately narrow — an `ArgumentError` (permanent status, bad query) and a plain
`ErrorException` are not.

When `err` carries an HTTP error status ([`error_status`](@ref)) that status decides, so a
401/403/404 surfacing as a `Downloads.RequestError` is permanent — matching
[`check_response`](@ref) — rather than transient by virtue of its type.
"""
function is_transient(err)
    status = error_status(err)
    status >= 400 && return is_transient_status(status)
    return err isa TransientError ||
           err isa HTTP.Exceptions.ConnectError ||
           err isa HTTP.Exceptions.TimeoutError ||
           err isa HTTP.Exceptions.RequestError ||
           err isa Downloads.RequestError ||
           err isa Base.IOError ||
           err isa EOFError
end

# A response body can be a whole HTML error page; keep the message readable.
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

Throw for an error response: [`TransientError`](@ref) if retrying could help, an
`ArgumentError` saying what to fix if it cannot. Returns `nothing` otherwise.
"""
function check_response(r, context::AbstractString)
    r.status < 400 && return nothing
    detail = body_excerpt(r)
    if is_transient_status(r.status)
        throw(TransientError(context, r.status, detail, retry_after_seconds(r)))
    elseif r.status == 401
        throw(
            ArgumentError(
                """
                Earthdata Login rejected the token ($(context), HTTP 401).

                $(detail)

                Tokens expire after 60 days. Check EARTHDATA_TOKEN, or list and create one
                at $(token_page_url).
                """,
            ),
        )
    elseif r.status == 403
        throw(
            ArgumentError(
                """
                Earthdata accepted the token but refused the request ($(context), HTTP 403).

                $(detail)

                This is nearly always an unaccepted end-user licence or an unapproved
                application rather than a bad token. Log in at
                https://urs.earthdata.nasa.gov/ and approve the DAAC application, then try
                again. Retrying without doing so cannot help.
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

Call `f`, retrying while it fails temporarily (see [`is_transient`](@ref)) with exponential
backoff from `retry_base` up to `retry_max_backoff`. Other errors propagate on the first
attempt, and the last failure is rethrown as-is so the user sees the service's own message.

`deadline` is an absolute `time()` bounding the retrying, and it — not `attempts` — is what
should normally stop a run. A `Retry-After` from the server overrides the backoff upward.
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
            verbose && @warn "Temporary Earthdata failure; retrying" context attempt backoff_s =
                round(backoff; digits=1) error = sprint(showerror, err)
            sleep(backoff)
        end
    end
end

"""
    classifying_requester(inner=HTTP.request, context="CMR search")

Wrap a `requester` (as accepted by `request`, [`granules`](@ref) and [`collections`](@ref))
so a temporary status throws [`TransientError`](@ref) instead of being turned into a plain
`ErrorException` by `parse_cmr_error`.

Only temporary statuses are intercepted. The rest are passed through untouched, so
`parse_cmr_error`'s reading of CMR's `errors` array is still what the caller sees.

```julia
granules(short_name="MCD43A3", version="061", requester=classifying_requester())
```
"""
function classifying_requester(inner=HTTP.request, context::AbstractString="CMR search")
    return function (args...; kwargs...)
        r = inner(args...; kwargs...)
        if is_transient_status(r.status)
            throw(TransientError(context, r.status, body_excerpt(r), retry_after_seconds(r)))
        end
        return r
    end
end
