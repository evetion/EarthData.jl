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

# Custom downloader for Julia 1.6 which doensn't have NETRC + Cookie support
# This is a method because it will segfault if precompiled.
function custom_downloader()
    downloader = Downloads.Downloader()
    easy_hook =
        (easy, _) -> begin
            Downloads.Curl.setopt(easy, Downloads.Curl.CURLOPT_NETRC, Downloads.Curl.CURL_NETRC_OPTIONAL)
            Downloads.Curl.setopt(easy, Downloads.Curl.CURLOPT_COOKIEFILE, "")
        end
    downloader.easy_hook = easy_hook
    return downloader
end

function _download(kwargs...)
    downloader = custom_downloader()
    Downloads.download(kwargs...; downloader=downloader)
end

function _request(args...; kwargs...)
    downloader = custom_downloader()
    Downloads.request(args...; kwargs..., downloader=downloader)
end

function download(url, fn; kwargs...)
    _download(url, fn; kwargs...)
end
