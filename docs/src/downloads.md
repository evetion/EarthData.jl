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

## Errors and retries

**Retrying is not this package's job.** HTTP.jl's `retrylayer` is on by default (4 attempts,
exponential backoff), and `aria2c` — which `download` uses for batches — has `--max-tries`,
`--retry-wait` and `--continue`. Reach for those.

What a general-purpose client cannot know is what a DAAC *means* by a status, and in one case
its default is wrong for Earthdata: HTTP.jl's retryable set includes **403**, but a 403 from
a DAAC nearly always means the account has not accepted the collection's licence, so retrying
spends the attempt budget on a request that can never succeed.

So EarthData.jl contributes the classification, not the loop:

- **Temporary** — 5xx, 408, 429. The service said nothing about the request.
- **Permanent** — 400, 401, 403, 404, each with an `ArgumentError` naming the fix. A 401
  means the token is missing or expired (they last 60 days); a 403 means the licence.

The split is by status, not by exception type. `Downloads.download` raises
`Downloads.RequestError` both for a transport fault and for any HTTP error status, so a 403
and a 503 arrive as the same type and only the status tells them apart.

For searches, `earthdata_requester` plugs into the existing `requester` hook:

```julia
granules(short_name="MCD43A3", version="061", requester=earthdata_requester())
```

This is needed because the search path passes `status_exception=false`, which switches off
HTTP.jl's *status-based* retrying: with no exception thrown, `retryable(::StatusError)` is
never consulted, so a CMR 503 comes back as a plain 503 response after one attempt.
(Connection faults still retry, since those throw either way.) Pair it with `retry_check` to
stop 403s being retried:

```julia
HTTP.request(...; retry_check=EarthData.retry_check)
```

One exception keeps its own retry: `get_s3_credentials`. A DAAC's `/s3credentials` goes over
`Downloads`, so neither `retrylayer` nor `aria2c` covers it, and it was the one call with no
retry at all.

## S3 downloads

S3 support is provided by the optional `AWSS3` extension. After loading `AWSS3`,
EarthData.jl can request temporary Earthdata Cloud S3 credentials and download
S3 URLs:

```julia
using AWSS3

config = EarthData.create_aws_config("nsidc", "us-west-2")
EarthData.s3download("s3://bucket/path/file.h5", "file.h5", config)
```
