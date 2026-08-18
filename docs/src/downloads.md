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

## Earthdata credentials

NASA Earthdata downloads require credentials. Store them in your `.netrc` file
with `netrc!`:

```julia
EarthData.netrc!("earthdata_username", "earthdata_password")
```

The file is plaintext, so use the same care you would use for any credential
file.

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

Not every failure means the same thing, so EarthData.jl sorts them into two groups:

- **Temporary** — 5xx, 408, 429, and connection faults. The service said nothing about the
  request, so waiting and trying again can work. These throw `TransientError`.
- **Permanent** — 400, 401, 403, 404. These throw an `ArgumentError` saying what to fix. A
  403 from a DAAC nearly always means the account has not accepted the collection's licence,
  and retrying cannot help.

Getting this wrong is costly either way: one brief 502 should not end an hours-long run, and
a 403 should not be retried until the deadline.

`with_retries` applies the split, backing off exponentially up to a minute. A `Retry-After`
from the server takes priority, capped at five minutes. Pass `deadline` (an absolute
`time()`) to bound the whole thing — the attempt cap is set high enough to wait out a
maintenance window, so `deadline` is what should normally stop a run.

```julia
EarthData.with_retries(context="my download") do
    download(url, path)
end
```

Searches are classified through the existing `requester` hook:

```julia
granules(short_name="MCD43A3", version="061", requester=classifying_requester())
```

Without it a CMR 503 arrives as a generic `ErrorException` from `parse_cmr_error`, which
looks the same as a rejected query.

## S3 downloads

S3 support is provided by the optional `AWSS3` extension. After loading `AWSS3`,
EarthData.jl can request temporary Earthdata Cloud S3 credentials and download
S3 URLs:

```julia
using AWSS3

config = EarthData.create_aws_config("nsidc", "us-west-2")
EarthData.s3download("s3://bucket/path/file.h5", "file.h5", config)
```
