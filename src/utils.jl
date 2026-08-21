import Aria2_jll

"""
    netrc!(username, password)

Writes/updates a .netrc file for ICESat-2 and GEDI downloads. A .netrc is a plaintext
file containing your username and password for NASA EarthData and DAACs, and can be automatically
used by Julia using `Downloads` and tools like `wget`, `curl` among others.
"""
function netrc!(username, password)
    if Sys.iswindows()
        fn = joinpath(homedir(), "_netrc")
    else
        fn = joinpath(homedir(), ".netrc")
    end

    open(fn, "a") do f
        write(f, "\n")
        write(f, "machine urs.earthdata.nasa.gov login $username password $(password)\n")
    end
    fn
end

# `Downloads` enables both `CURLOPT_NETRC` (optional) and session cookies by default —
# JuliaLang/Downloads.jl#98, released in Downloads 1.5.0, and Julia 1.10 ships 1.6.0. The
# `custom_downloader` that used to set exactly those two options was a restatement of the
# default, so Earthdata's redirect-based auth works without a hook.
function download(url::AbstractString, fn::AbstractString; kwargs...)
    if startswith(url, "s3:")
        s3download(url, fn)
    else
        Downloads.download(url, fn; kwargs...)
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
)
    folder = normpath(abspath(folder))
    mkpath(folder)
    paths = download_paths(urls, folder)

    if !aria2 || any(url -> startswith(url, "s3:"), urls)
        for (url, path) in zip(urls, paths)
            isfile(path) || download(url, path)
        end
    else
        fn = write_urls(urls)
        try
            runner(`$(Aria2_jll.aria2c()) -i $fn -c -d $folder`)
        finally
            rm(fn; force=true)
        end
    end

    return paths
end
