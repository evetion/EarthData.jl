"""
Saying what an Earthdata failure means, in the cases where the status alone misleads.

Retrying is not this package's job: HTTP.jl has `retrylayer` (on by default, 4 attempts) and
`aria2c` has `--max-tries`/`--retry-wait`/`--continue`. What neither can know is what a DAAC
means by a given status, and for one status HTTP.jl's default is wrong here:

- HTTP.jl's retryable set is `(403, 408, 409, 429, 500, 502, 503, 504, 599)`. A 403 from a
  DAAC nearly always means the account has not accepted the collection's licence, so retrying
  it spends the attempt budget on a request that can never succeed. See [`retry_check`](@ref).
- **401** means the token is missing, malformed or expired (they last 60 days), not that the
  request was wrong.

Permanent here is 400, 401, 403 and 404; temporary is 5xx, 408 and 429. The status decides,
not the exception type: `Downloads.RequestError` is thrown both for a transport fault and for
any HTTP error status, so a 403 and a 503 reach us as the same type. See
[`error_status`](@ref).
"""

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

"""
    retry_after_seconds(response) -> Float64

Seconds the server asked us to wait, from `Retry-After`, or `0.0` when the header is absent
or unparseable. Only the delta-seconds form is read; clamped to `retry_after_max`.

Reads `response.headers` directly rather than going through `HTTP.header`, which only
accepts an `HTTP.Messages.Message` — a `Downloads.Response` is a plain struct, and that is
the shape `/s3credentials` fails with.
"""
function retry_after_seconds(response)
    for (name, value) in response.headers
        lowercase(String(name)) == "retry-after" || continue
        seconds = tryparse(Float64, strip(String(value)))
        isnothing(seconds) && return 0.0
        return clamp(seconds, 0.0, retry_after_max)
    end
    return 0.0
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
    with_retries(f; context, attempts=4, verbose=true, deadline=Inf) -> f()

Retry `f` while it fails temporarily (see [`is_transient`](@ref)), backing off exponentially.

Deliberately kept for one caller: `get_s3_credentials`. A DAAC's `/s3credentials` goes over
`Downloads` rather than HTTP.jl, so neither `retrylayer` nor `aria2c` covers it, and it was
the one call with no retry of its own — `main` failed against it with
`Connection timed out after 30017 milliseconds` on valid credentials.

Anything going over HTTP.jl should use its own `retries`/`retry_check` instead of this, and
anything downloading should use `aria2c`. `attempts` matches HTTP.jl's default of 4 rather
than trying to outlast a maintenance window; pass `deadline` (an absolute `time()`) to bound
the whole thing.
"""
function with_retries(
    f;
    context::AbstractString,
    attempts::Integer=4,
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
            backoff = min(2.0^attempt, 60.0)
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
    retry_check(s, ex, req, resp, resp_body) -> Bool

A `retry_check` for HTTP.jl's `retrylayer`, so a DAAC 403 is not retried.

HTTP.jl retries `(403, 408, 409, 429, 500, 502, 503, 504, 599)`. The 403 is defensible for a
generic client — some CDNs do return a transient one — but for Earthdata it means an
unaccepted end-user licence, and retrying it can never succeed.

```julia
HTTP.request(method, url, headers; retry_check=EarthData.retry_check)
```
"""
retry_check(s, ex, req, resp, resp_body) =
    !isnothing(resp) && is_transient_status(resp.status)

"""
    earthdata_requester(inner=HTTP.request, context="CMR search")

A `requester` (as accepted by `request`, [`granules`](@ref) and [`collections`](@ref)) that
re-throws a temporary CMR status as [`TransientError`](@ref), handing it back to HTTP.jl's
own retry layer instead of letting `parse_cmr_error` flatten it into an `ErrorException`.

Needed because the search path passes `status_exception=false`, which switches off HTTP.jl's
*status-based* retrying: with no exception thrown, `retryable(::StatusError)` is never
consulted, so a CMR 503 comes back as a plain 503 response after a single attempt. Connection
faults are unaffected — those throw either way, and HTTP.jl already retries them.

A permanent status is passed through untouched, so `parse_cmr_error`'s reading of CMR's
`errors` array is still what the caller sees.

```julia
granules(short_name="MCD43A3", version="061", requester=earthdata_requester())
```
"""
function earthdata_requester(inner=HTTP.request, context::AbstractString="CMR search")
    return function (args...; kwargs...)
        r = inner(args...; kwargs...)
        if is_transient_status(r.status)
            throw(TransientError(context, r.status, body_excerpt(r), retry_after_seconds(r)))
        end
        return r
    end
end
