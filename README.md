# EarthData

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://evetion.github.io/EarthData.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://evetion.github.io/EarthData.jl/dev/)
[![Build Status](https://github.com/evetion/EarthData.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/evetion/EarthData.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/evetion/EarthData.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/evetion/EarthData.jl)

A Julia interface to NASA's Common Metadata Repository (CMR), the metadata
service behind [Earthdata Search](https://search.earthdata.nasa.gov).
EarthData.jl searches granules and collections, parses UMM JSON responses into
Julia structs, extracts HTTPS and S3 download URLs, and downloads data with
Earthdata credential handling.

## Installation

```julia
] add EarthData
```

## Usage
```julia
julia> using EarthData

# Search for GEDI L2A granules
julia> gg = granules(short_name="GEDI02_A")
10-element Vector{EarthData.Granules.UMM_G}:
 GEDI02_A: GEDI02_A_2019108002012_O01959_01_T03909_02_003_01_V002
 GEDI02_A: GEDI02_A_2019108002012_O01959_02_T03909_02_003_01_V002
 GEDI02_A: GEDI02_A_2019108002012_O01959_03_T03909_02_003_01_V002
 ...

# A single granule shows its collection short name and granule id
julia> gg[1]
GEDI02_A: GEDI02_A_2019108002012_O01959_01_T03909_02_003_01_V002

julia> gg[1].RelatedUrls[1].URL
"https://e4ftl01.cr.usgs.gov//GEDI_L1_L2/GEDI/GEDI02_A.002/2019.04.18/GEDI02_A_2019108002012_O01959_01_T03909_02_003_01_V002.h5"

# Search across every CMR page using CMR-Search-After pagination
julia> all_gg = granules(short_name="GEDI02_A", page_size=2000, all=true)

# Search collections
julia> cc = collections(short_name="GEDI02_A")

# Extract HTTPS or S3 URLs from UMM search results
julia> https_urls(gg[1])

julia> s3_urls(gg[1])

# Store Earthdata credentials in .netrc, then download one file
julia> EarthData.netrc!("earthdata_username", "earthdata_password")

julia> download(download_url(gg[1]), "GEDI02_A_example.h5")

# Download many HTTPS URLs with aria2c
julia> download(gg, "data")
```

See the [documentation](https://evetion.github.io/EarthData.jl/dev/) for
pagination, collection search, URL helpers, batch downloads, and optional S3
access with AWSS3.jl.
