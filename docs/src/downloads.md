```@meta
CurrentModule = EarthData
DocTestSetup = quote
    using EarthData
end
```

# Downloads and URLs

Search results usually contain several related URLs. EarthData.jl provides
helpers for extracting HTTPS and S3 URLs from UMM records and for downloading
individual files or batches of files.

## URL helpers

Use `urls` to collect every related URL, or filter by scheme with `https_urls`,
`s3_urls`, or `download_url`:

```jldoctest url_helpers
julia> struct ExampleItem <: EarthData.AbstractJSON
           RelatedUrls::Vector{NamedTuple{(:URL,), Tuple{String}}}
       end

julia> item = ExampleItem([(URL = "https://example.test/G1.h5",), (URL = "s3://example-bucket/G1.h5",)]);

julia> https_urls(item)
1-element Vector{String}:
 "https://example.test/G1.h5"

julia> s3_urls(item)
1-element Vector{String}:
 "s3://example-bucket/G1.h5"

julia> download_url(item)
"https://example.test/G1.h5"
```

The same helpers also accept vectors of UMM records:

```julia
gg = granules(short_name="GEDI02_A")
https_urls(gg)
s3_urls(gg)
```

### Selecting the data file

A record's related URLs are not all data. A single MCD43A3 granule, for example, carries
eight: the HTTPS file, its S3 copy, a DOI landing page, a metadata sidecar, browse imagery
and a cloud-credentials endpoint. `https_urls` returns most of those, so filter on
`RelatedUrls[].Type` instead — `data_urls` does exactly that, keeping only `"GET DATA"`:

```julia
data_urls(first(gg))          # the file
download(gg, "data"; type="GET DATA")
```

The S3 copy of the same file is typed `"GET DATA VIA DIRECT ACCESS"`:

```julia
urls(first(gg); scheme=:s3, type="GET DATA VIA DIRECT ACCESS")
```

### Granule sizes

`granule_size` reports a granule's size in bytes:

```julia
granule_size(first(gg))
```

It prefers `SizeInBytes`, and otherwise converts `Size` using the record's `SizeUnit`.
`Size` alone is unit-less — providers commonly report megabytes — so reading it without
the unit understates the size by a factor of about a million.

## Earthdata credentials

NASA Earthdata downloads require credentials. Store them in your `.netrc` file
with `netrc!`:

```julia
EarthData.netrc!("earthdata_username", "earthdata_password")
```

The file is plaintext, so use the same care you would use for any credential
file.

### Bearer tokens

Earthdata Login also issues bearer tokens, which is the credential an HTTP client
needs when it sets its own headers rather than delegating to curl's `.netrc`
support. `EarthData.token()` resolves one from `ENV["EARTHDATA_TOKEN"]`, else the
first non-comment line of `~/.edl_token`, and `auth_headers` builds the header:

```julia
headers = EarthData.auth_headers()          # Authorization: Bearer <token>
Downloads.download(data_urls(first(gg))[1], "granule.h5"; headers)
```

Resolution never touches the network. To obtain a token from your `.netrc`
credentials instead, call `EarthData.token_from_netrc()` explicitly:

```julia
ENV["EARTHDATA_TOKEN"] = EarthData.token_from_netrc()
```

!!! warning "Two concurrent tokens, maximum"
    An account may hold two live tokens; requesting a third returns HTTP 403.
    `token_from_netrc()` lists existing tokens and returns the first, so it cannot
    exhaust the quota; `token_from_netrc(create=true)` will consume a slot when the
    account has none. Never call either from a retry loop. Tokens last 60 days.

## Downloading files

Download one URL to a path:

```julia
gg = granules(short_name="GEDI02_A")
download(download_url(first(gg)), "GEDI02_A_example.h5")
```

Download many HTTPS URLs into a folder. EarthData.jl uses `aria2c` by default for
batch HTTPS downloads:

```julia
download(gg, "data")
```

To write a URL list for another tool:

```julia
write_urls("urls.txt", gg)
```

## S3 downloads

S3 support is provided by the optional `AWSS3` extension. After loading `AWSS3`,
EarthData.jl can request temporary Earthdata Cloud S3 credentials and download
S3 URLs:

```julia
using AWSS3

config = EarthData.create_aws_config("nsidc", "us-west-2")
EarthData.s3download("s3://bucket/path/file.h5", "file.h5", config)
```
