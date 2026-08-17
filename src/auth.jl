"""
Earthdata Login (EDL) bearer tokens.

`netrc!` writes a username and password for tools that speak `.netrc`. A bearer token is
the other credential EDL issues, and it is what an HTTP client needs when it sets its own
headers — `Authorization: Bearer <token>` — rather than delegating to curl's netrc support.

Resolution ([`token`](@ref)) is deliberately offline. Obtaining a token
([`token_from_netrc`](@ref)) is a separate, explicit call, because an account may hold only
**two** live tokens and creation must never be reachable from a retry loop.
"""

const token_page = "https://urs.earthdata.nasa.gov/users/tokens"
const token_api = "https://urs.earthdata.nasa.gov/api/users"

"""
    token() -> String

The Earthdata Login bearer token, from the environment or a token file.

Searches, in order:

1. `ENV["EARTHDATA_TOKEN"]`
2. `~/.edl_token` (first non-empty, non-comment line)

Throws an `ErrorException` with setup instructions when neither is present.

This never contacts the network. To obtain a token from `.netrc` credentials instead, call
[`token_from_netrc`](@ref) explicitly.

`EARTHDATA_TOKEN` is a community convention rather than a NASA-defined variable; no NASA
tooling reads it for you.

Treat the returned string as a secret: it authenticates as the account for 60 days.
"""
function token()
    tok = get(ENV, "EARTHDATA_TOKEN", "")
    isempty(strip(tok)) || return String(strip(tok))

    path = joinpath(homedir(), ".edl_token")
    if isfile(path)
        for line in readlines(path)
            s = strip(line)
            (isempty(s) || startswith(s, "#")) && continue
            return String(s)
        end
    end

    error("""
    No NASA Earthdata Login token found. Create one at
        $(token_page)
    and either

        export EARTHDATA_TOKEN="your-token-here"

    or write it to ~/.edl_token. A token lasts 60 days, and an account may hold at most
    two at a time — reuse an existing one rather than requesting a third, which fails.

    Alternatively, with ~/.netrc credentials for urs.earthdata.nasa.gov in place:
        EarthData.token_from_netrc()
    """)
end

"""
    token_from_netrc(; create=false, machine="urs.earthdata.nasa.gov") -> String

Fetch an Earthdata Login bearer token using the username and password stored in `.netrc`.

This is a network call, kept out of [`token`](@ref) on purpose: a credential lookup that
can hit the network is a lookup that can hang or rate-limit inside a retry loop.

!!! warning "Two concurrent tokens, maximum"
    EDL allows an account two live tokens; requesting a third returns HTTP 403. With
    `create=false` (the default) this only *lists* tokens and returns the first, so it
    cannot exhaust the quota. `create=true` will consume the second slot when none exists.
    Do not call this from a retry loop.
"""
function token_from_netrc(;
    create::Bool=false,
    machine::AbstractString="urs.earthdata.nasa.gov",
    requester=HTTP.request,
)
    user, pass = netrc_credentials(machine)
    auth = "Basic " * Base64.base64encode(string(user, ":", pass))
    headers = ["Authorization" => auth, "Accept" => "application/json"]

    endpoint = create ? "$(token_api)/token" : "$(token_api)/tokens"
    method = create ? "POST" : "GET"
    r = requester(method, endpoint, headers; status_exception=false)
    if r.status >= 400
        error("""
        Earthdata Login rejected the token request ($(method) $(endpoint), HTTP $(r.status)):

        $(String(r.body))

        HTTP 401 means the .netrc credentials for "$(machine)" are wrong. HTTP 403 on a
        creation request usually means the two-token limit is already reached — list them
        at $(token_page) and reuse one.
        """)
    end

    body = JSON3.read(String(r.body))
    # `GET /tokens` answers with an array, `POST /token` with a single object.
    entry = body isa JSON3.Array ? (isempty(body) ? nothing : first(body)) : body
    if isnothing(entry) || !haskey(entry, :access_token)
        error("""
        Earthdata Login returned no usable token. With `create=false` this means the
        account currently holds none; call `token_from_netrc(create=true)` or create one
        at $(token_page).
        """)
    end
    return String(entry.access_token)
end

"""
    netrc_credentials(machine="urs.earthdata.nasa.gov"; path=nothing) -> (login, password)

Read `login` and `password` for `machine` from `.netrc`, the counterpart to
[`netrc!`](@ref).

`.netrc` is a whitespace-separated token stream, so the tokens are scanned in order and the
values following the target `machine` are taken until the next `machine` or `default`
entry. The `macdef` form is not supported. `path` defaults to `ENV["NETRC"]`, else
`~/.netrc` (`~/_netrc` on Windows).
"""
function netrc_credentials(
    machine::AbstractString="urs.earthdata.nasa.gov";
    path=nothing,
)
    default_name = Sys.iswindows() ? "_netrc" : ".netrc"
    file = something(path, get(ENV, "NETRC", joinpath(homedir(), default_name)))
    isfile(file) || error("""
        No .netrc file at $(file), so Earthdata Login credentials cannot be read.
        Add a stanza:

            machine $(machine) login YOUR_USERNAME password YOUR_PASSWORD

        and `chmod 600` it, or use `EarthData.netrc!(username, password)`.
        """)

    tokens = split(read(file, String))
    login = password = nothing
    inside = false
    i = 1
    while i <= length(tokens)
        t = tokens[i]
        if t == "machine"
            inside = i + 1 <= length(tokens) && tokens[i + 1] == machine
            i += 2
            continue
        elseif t == "default"
            inside = true
            i += 1
            continue
        elseif inside && t in ("login", "password") && i + 1 <= length(tokens)
            t == "login" ? (login = tokens[i + 1]) : (password = tokens[i + 1])
            i += 2
            !isnothing(login) && !isnothing(password) && break
            continue
        end
        i += 1
    end

    (isnothing(login) || isnothing(password)) &&
        error("$(file) has no login/password for machine \"$(machine)\".")
    return String(login), String(password)
end

"""
    auth_headers(; bearer=EarthData.token()) -> Vector{Pair{String,String}}

`Authorization: Bearer` header for an Earthdata Login token, for clients that set their own
headers rather than relying on `.netrc`.
"""
auth_headers(; bearer=token()) = ["Authorization" => "Bearer $(bearer)"]
