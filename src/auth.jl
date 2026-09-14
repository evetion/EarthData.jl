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
    netrc_path() -> String

The `.netrc` file this package reads credentials from and writes them to.

`~/.netrc`, except on Windows, where `~/_netrc` is used when it exists and `~/.netrc` does
not. That is the order libcurl resolves the two names in, so a download and this package
read the same file.
"""
function netrc_path()
    path = joinpath(homedir(), ".netrc")
    if Sys.iswindows() && !isfile(path)
        legacy = joinpath(homedir(), "_netrc")
        isfile(legacy) && return legacy
    end
    return path
end

"""
    netrc!(username, password; machine="urs.earthdata.nasa.gov", path=netrc_path()) -> String

Store Earthdata Login credentials in `.netrc`, replacing any existing stanza for `machine`.

`.netrc` is a plaintext file that `Downloads`, curl, wget and aria2c read to authenticate,
which is how a NASA download gets its credentials without a token. The file is left at mode
`600`, on Windows too — `chmod` there rewrites the file's ACL to grant the owner alone.

Replacement rather than addition is what makes a correction take effect: curl uses the
*first* stanza matching a machine, so a second one for the same machine is never read.
Other machines, and comments, are left as they are.

A credential containing whitespace cannot be represented in `.netrc`, so it raises here
instead of writing a file that parses as something else.
"""
function netrc!(
    username,
    password;
    machine::AbstractString="urs.earthdata.nasa.gov",
    path::AbstractString=netrc_path(),
)
    for (name, value) in
        (("username", username), ("password", password), ("machine", machine))
        netrc_token(name, value)
    end

    lines = isfile(path) ? netrc_without(readlines(path), machine) : String[]
    while !isempty(lines) && isempty(strip(last(lines)))
        pop!(lines)
    end
    open(path, "w") do io
        for line in lines
            println(io, line)
        end
        println(io, "machine $(machine) login $(username) password $(password)")
    end
    chmod(path, 0o600)
    return path
end

"""
    netrc_token(name, value) -> String

`value` as a `.netrc` token, or an `ArgumentError` if it cannot be one.

`.netrc` separates tokens on whitespace and has no quoting or escaping, so a value
containing whitespace would be read back as different values than were written.
"""
function netrc_token(name::AbstractString, value)
    s = string(value)
    isempty(s) &&
        throw(ArgumentError("`$(name)` is empty; .netrc has no way to write that."))
    any(isspace, s) && throw(
        ArgumentError(
            "`$(name)` contains whitespace, which .netrc uses to separate tokens, so it " *
            "cannot be stored there.",
        ),
    )
    return s
end

"""
    netrc_without(lines, machine) -> Vector{String}

`lines` with the stanza for `machine` removed.

A stanza runs from `machine <name>` to the next `machine` or `default`, which is not
necessarily a line boundary — but lines are the unit removed, so comments and the
formatting of other machines survive. A line carrying both this machine's tokens and
another's cannot be removed without rewriting it, and raises.
"""
function netrc_without(lines, machine::AbstractString)
    kept = String[]
    inside = false
    for line in lines
        if startswith(lstrip(line), "#")
            push!(kept, line)
            continue
        end
        tokens = split(line)
        target = other = false
        i = 1
        while i <= length(tokens)
            if tokens[i] == "machine"
                inside = i + 1 <= length(tokens) && tokens[i + 1] == machine
                i += 2
            elseif tokens[i] == "default"
                inside = false
                i += 1
            else
                i += 1
            end
            inside ? (target = true) : (other = true)
        end
        target &&
            other &&
            throw(
                ArgumentError(
                    "This .netrc line holds both \"$(machine)\" and another machine, so " *
                    "the stanza cannot be replaced without rewriting the line: " *
                    "$(repr(line))",
                ),
            )
        target || push!(kept, line)
    end
    return kept
end

"""
    token() -> String

The Earthdata Login bearer token, from the environment or a token file.

Searches, in order:

1. `ENV["EARTHDATA_TOKEN"]`
2. `~/.edl_token` (first non-empty, non-comment line)

Throws an `ErrorException` with setup instructions when neither is present. Use
[`credentials`](@ref) to resolve whatever credential is available, including none.

This never contacts the network. To obtain a token from `.netrc` credentials instead, call
[`token_from_netrc`](@ref) explicitly.

`EARTHDATA_TOKEN` is a community convention rather than a NASA-defined variable; no NASA
tooling reads it for you.

Treat the returned string as a secret: it authenticates as the account for 60 days.
"""
function token()
    tok = token_from_env()
    isnothing(tok) || return tok
    tok = token_from_file()
    isnothing(tok) || return tok

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

# An empty variable counts as absent: a shell that exports it unset should fall through to
# the next source rather than send an empty bearer.
function token_from_env()
    tok = strip(get(ENV, "EARTHDATA_TOKEN", ""))
    return isempty(tok) ? nothing : String(tok)
end

function token_from_file(path=joinpath(homedir(), ".edl_token"))
    isfile(path) || return nothing
    for line in readlines(path)
        s = strip(line)
        (isempty(s) || startswith(s, "#")) && continue
        return String(s)
    end
    return nothing
end

"""
    Auth

A resolved Earthdata credential, or the absence of one.

`kind` is `:bearer`, `:netrc` or `:anonymous`, and `source` names where it came from, so a
rejection can say which credential was rejected rather than just that authentication failed.

`:netrc` carries no secret. curl, `Downloads` and aria2c read `.netrc` themselves, so the
file stays the single place the username and password live.
"""
struct Auth
    kind::Symbol
    source::String
    bearer::Union{Nothing,String}
end

Auth(kind::Symbol, source::AbstractString) = Auth(kind, String(source), nothing)

Base.show(io::IO, auth::Auth) = print(io, "Auth(", auth.kind, " from ", auth.source, ")")

"""
    credentials(; machine="urs.earthdata.nasa.gov") -> Vector{Auth}

Every Earthdata credential available, in the order they should be tried:

1. `ENV["EARTHDATA_TOKEN"]`
2. `~/.edl_token`
3. `~/.netrc`
4. anonymous

The anonymous entry is always last and always present, so this never throws and never
returns empty: much of what CMR indexes is public, and refusing to proceed without a
credential would fail those downloads for no reason.

More than one entry is returned on purpose. A bearer token that has expired will be
rejected even though a working `.netrc` sits behind it, and curl does not fall back on its
own, so `download` retries with the next entry.
"""
function credentials(; machine::AbstractString="urs.earthdata.nasa.gov")
    found = Auth[]

    tok = token_from_env()
    isnothing(tok) || push!(found, Auth(:bearer, "ENV[\"EARTHDATA_TOKEN\"]", tok))

    tok = token_from_file()
    isnothing(tok) || push!(found, Auth(:bearer, "~/.edl_token", tok))

    path = netrc_path()
    if isfile(path)
        # Presence of a stanza is what matters; the secret itself stays in the file.
        credentials_exist = try
            netrc_credentials(machine; path)
            true
        catch
            false
        end
        credentials_exist && push!(found, Auth(:netrc, path))
    end

    push!(found, Auth(:anonymous, "no credential"))
    return found
end

"""
    login(; machine="urs.earthdata.nasa.gov", requester=HTTP.request) -> Auth

Verify the first available Earthdata credential against Earthdata Login and return it.

Pass the result as `auth` to `download` to skip resolution on every call. Searching is
[`credentials`](@ref); this additionally proves the credential works, so a wrong password is
reported now rather than midway through a download.

Throws when a credential is present but rejected. Returns the anonymous [`Auth`](@ref) when
no credential exists at all, since public data needs none.

Verification is one request against `/api/users/tokens`, which authenticates a bearer and a
username/password alike. EDL rate-limits it and answers 5xx once tripped, so a transient
failure is reported as such rather than as a bad credential.
"""
function login(;
    machine::AbstractString="urs.earthdata.nasa.gov",
    requester=HTTP.request,
)
    auth = first(credentials(; machine))
    auth.kind === :anonymous && return auth

    headers = if auth.kind === :netrc
        # `.netrc` holds a username and password, which this endpoint takes as Basic auth.
        user, pass = netrc_credentials(machine)
        ["Authorization" => "Basic " * Base64.base64encode(string(user, ":", pass))]
    else
        auth_headers(auth)
    end
    push!(headers, "Accept" => "application/json")

    r = requester("GET", "$(token_api)/tokens", headers; status_exception=false)
    # `check_response` separates a rejected credential from a rate-limited endpoint, and
    # truncates the HTML error page EDL serves.
    check_response(r, "verifying the credential from $(auth.source)")
    return auth
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

Each line is scanned for `machine`, `login` and `password` tokens, carrying the current
machine across lines so a stanza may be written on one line or several. Comments are
skipped and the `macdef` form is not supported. `path` defaults to [`netrc_path`](@ref).
"""
function netrc_credentials(
    machine::AbstractString="urs.earthdata.nasa.gov";
    path=nothing,
)
    file = something(path, netrc_path())
    isfile(file) || error("""
        No .netrc file at $(file), so Earthdata Login credentials cannot be read.
        Add a stanza:

            machine $(machine) login YOUR_USERNAME password YOUR_PASSWORD

        and `chmod 600` it, or use `EarthData.netrc!(username, password)`.
        """)

    login = password = nothing
    inside = false
    for line in eachline(file)
        startswith(lstrip(line), "#") && continue
        tokens = split(line)
        i = 1
        while i <= length(tokens)
            t = tokens[i]
            if t == "machine"
                # A named machine ends the previous stanza whether or not it is the target,
                # so credentials never leak from one machine's stanza into another's.
                inside = i + 1 <= length(tokens) && tokens[i + 1] == machine
                i += 2
            elseif t == "default"
                inside = true
                i += 1
            elseif inside && t in ("login", "password") && i + 1 <= length(tokens)
                t == "login" ? (login = tokens[i + 1]) : (password = tokens[i + 1])
                i += 2
            else
                i += 1
            end
        end
        # The first matching stanza wins, which is also the one curl uses.
        isnothing(login) || isnothing(password) || break
    end

    (isnothing(login) || isnothing(password)) &&
        error("$(file) has no login/password for machine \"$(machine)\".")
    return String(login), String(password)
end

"""
    auth_headers(; bearer=EarthData.token()) -> Vector{Pair{String,String}}
    auth_headers(auth::Auth) -> Vector{Pair{String,String}}

`Authorization: Bearer` header for an Earthdata Login token, for clients that set their own
headers rather than relying on `.netrc`.

Empty for a `:netrc` or `:anonymous` [`Auth`](@ref): curl and `Downloads` read `.netrc`
themselves, and an anonymous request carries no header at all.
"""
auth_headers(; bearer=token()) = ["Authorization" => "Bearer $(bearer)"]

function auth_headers(auth::Auth)
    isnothing(auth.bearer) && return Pair{String,String}[]
    return auth_headers(bearer=auth.bearer)
end
