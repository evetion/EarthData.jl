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
# expired token would otherwise mask credentials that work. Any other status is not about
# who is asking, so it propagates untouched.
function download_with_fallback(url, fn, candidates; kwargs...)
    isempty(candidates) &&
        throw(ArgumentError("No credential to try; `credentials()` always offers one."))
    for (i, candidate) in enumerate(candidates)
        try
            return Downloads.download(url, fn; headers=auth_headers(candidate), kwargs...)
        catch err
            i == lastindex(candidates) && rethrow()
            error_status(err) in (401, 403) || rethrow()
            @warn "Earthdata rejected the credential; trying the next one." source =
                candidate.source next = candidates[i + 1].source
        end
    end
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

# aria2c's input file, with a bearer as a `header=` line rather than a `--header` argument:
# a command line is world-readable through `ps`, and `mktemp` creates this file mode 600.
# The indent is what marks a line as an option belonging to the URI above it.
function write_aria2_input(urls::AbstractVector{<:AbstractString}, bearer)
    fn, io = mktemp()
    try
        for url in urls
            println(io, url)
            isnothing(bearer) || println(io, "  header=Authorization: Bearer ", bearer)
        end
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
        # aria2c runs once over the whole batch, so it gets one credential rather than the
        # fallback chain. A bearer is not in `.netrc`, so it travels in the input file.
        bearer = (isnothing(auth) ? first(credentials()) : auth).bearer
        fn = write_aria2_input(urls, bearer)
        try
            # aria2c reads `$HOME/.netrc` and has no `_netrc` fallback, so naming the file
            # is what lets a Windows user with only `_netrc` download. It also requires
            # mode 600, which `netrc!` sets.
            runner(
                `$(Aria2_jll.aria2c()) --netrc-path=$(netrc_path()) -i $fn -c -d $folder`,
            )
        finally
            rm(fn; force=true)
        end
    end

    return paths
end
