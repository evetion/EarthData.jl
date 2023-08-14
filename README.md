# EarthData

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://evetion.github.io/EarthData.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://evetion.github.io/EarthData.jl/dev/)
[![Build Status](https://github.com/evetion/EarthData.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/evetion/EarthData.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/evetion/EarthData.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/evetion/EarthData.jl)

A Julia interface to search.earthdata.nasa.gov

## Installation

```julia
] add EarthData
```

## Usage
```julia
julia> using EarthData

# Search for all GEDI L2A granules
julia> gg = granules(short_name="GEDI02_A")
1000-element Vector{EarthData.UMM_G}:
 EarthData.UMM_G
 EarthData.UMM_G
 EarthData.UMM_G
 EarthData.UMM_G
 EarthData.UMM_G
 EarthData.UMM_G
 EarthData.UMM_G

# A single granule, with the non-empty fields shown by default
julia> g[1]
EarthData.UMM_G
        TemporalExtent
        CollectionReference
        RelatedUrls
        GranuleUR
        Platforms
        DataGranule
        MetadataSpecification
        PGEVersionClass
        Projects
        AdditionalAttributes
        ProviderDates
        SpatialExtent
        OrbitCalculatedSpatialDomains
        MeasuredParameters

julia> gg[1].RelatedUrls[1].URL
"https://e4ftl01.cr.usgs.gov//GEDI_L1_L2/GEDI/GEDI02_A.002/2019.04.18/GEDI02_A_2019108002012_O01959_01_T03909_02_003_01_V002.h5"
```

## Next
Implementing `collections` will be next on the list to implement.
