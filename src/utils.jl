import Aria2_jll

# Earthdata's redirect-based auth needs no hook of its own: `Downloads` enables both
# `CURLOPT_NETRC` (optional) and session cookies by default — JuliaLang/Downloads.jl#98,
# released in Downloads 1.5.0, and Julia 1.10 ships 1.6.0.
#
# A bearer token still has to be sent explicitly, since it lives outside `.netrc`.
function download(
    url::AbstractString,
    fn::AbstractString;
    auth::Union{Nothing,Auth}=nothing,
    kwargs...,
)
    if startswith(url, "s3:")
        return s3download(url, fn)
    end
    candidates = isnothing(auth) ? credentials() : [auth]
    return download_with_fallback(url, fn, candidates; kwargs...)
end

# Try each credential in turn. A bearer rejected with 401/403 must not end the download
# while a working `.netrc` is still untried — curl will not fall back on its own, so an
# expired token would otherwise mask credentials that work.
function download_with_fallback(url, fn, candidates; kwargs...)
    for (i, candidate) in enumerate(candidates)
        headers = auth_headers(candidate)
        try
            return Downloads.download(url, fn; headers, kwargs...)
        catch err
            last = i == lastindex(candidates)
            (last || !is_credential_rejection(err)) && rethrow()
            @warn "Earthdata rejected the credential; trying the next one." source =
                candidate.source next = candidates[i + 1].source
        end
    end
end

# 401 and 403 are the two statuses another credential could plausibly fix. Anything else is
# not about who is asking, so it propagates untouched.
function is_credential_rejection(err)
    err isa Downloads.RequestError || return false
    return err.response.status in (401, 403)
end

function write_urls(io::IO, urls::AbstractVector{<:AbstractString})
    for url in urls
        println(io, url)
    end
    return io
end

function write_urls(fn::AbstractString, urls::AbstractVector{<:AbstractString})
    open(fn, "w") do io
        write_urls(io, urls)
    end
    return abspath(fn)
end

function write_urls(urls::AbstractVector{<:AbstractString})
    fn, io = mktemp()
    try
        write_urls(io, urls)
    finally
        close(io)
    end
    return fn
end

function url_filename(url::AbstractString)
    name = basename(first(split(url, "?"; limit=2)))
    isempty(name) && throw(ArgumentError("Cannot determine a filename from URL: $url"))
    return name
end

function download_paths(urls::AbstractVector{<:AbstractString}, folder::AbstractString)
    [joinpath(folder, url_filename(url)) for url in urls]
end

# The bearer aria2c should send, or `nothing` when `.netrc` alone will do. aria2c runs once
# over the whole batch, so it gets a single credential rather than the fallback chain.
function aria2_bearer(auth::Union{Nothing,Auth})
    resolved = isnothing(auth) ? first(credentials()) : auth
    return resolved.bearer
end

function download(
    urls::AbstractVector{<:AbstractString},
    folder::AbstractString=".";
    aria2::Bool=true,
    runner=run,
    auth::Union{Nothing,Auth}=nothing,
)
    folder = normpath(abspath(folder))
    mkpath(folder)
    paths = download_paths(urls, folder)

    if !aria2 || any(url -> startswith(url, "s3:"), urls)
        # Resolve once rather than per file, so a fallback is not re-walked each time.
        resolved = isnothing(auth) ? credentials() : [auth]
        for (url, path) in zip(urls, paths)
            isfile(path) && continue
            if startswith(url, "s3:")
                s3download(url, path)
            else
                download_with_fallback(url, path, resolved)
            end
        end
    else
        fn = write_urls(urls)
        try
            # aria2c reads `$HOME/.netrc` and has no `_netrc` fallback, so naming the file
            # is what lets a Windows user with only `_netrc` download. It also requires
            # mode 600, which `netrc!` sets.
            #
            # A bearer token is not in `.netrc`, so it goes on the command line as a header.
            bearer = aria2_bearer(auth)
            cmd = `$(Aria2_jll.aria2c()) --netrc-path=$(netrc_path()) -i $fn -c -d $folder`
            isnothing(bearer) ||
                (cmd = `$cmd --header=$("Authorization: Bearer " * bearer)`)
            runner(cmd)
        finally
            rm(fn; force=true)
        end
    end

    return paths
end
