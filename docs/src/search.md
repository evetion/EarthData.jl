# Searching Earthdata

EarthData.jl searches CMR granule and collection endpoints and returns typed UMM
records:

```julia
using EarthData

granule_results = granules(short_name="GEDI02_A")
collection_results = collections(short_name="GEDI02_A")
```

The accepted keyword arguments are CMR search parameters. Use
`fieldnames(EarthData.GranuleRequest)`, `fieldnames(EarthData.CollectionRequest)`,
and `fieldnames(EarthData.QueryParams)` to inspect the supported names.

## Granules

`granules` returns `Vector{EarthData.Granules.UMM_G}`. Each record exposes the UMM-G
fields from NASA's schema as Julia struct fields:

```julia
gg = granules(short_name="GEDI02_A")
first(gg).GranuleUR
first(gg).RelatedUrls
```

By default, EarthData.jl requests one CMR page. Set `page_size` to control the
page size and `all=true` to continue through all pages using the
`CMR-Search-After` response header:

```julia
all_granules = granules(short_name="GEDI02_A", page_size=2000, all=true)
```

### Spatial subsetting

Granule searches accept CMR's spatial parameters — `bounding_box`, `point`, `line`,
`circle` and `polygon`:

```julia
gg = granules(
    short_name="MCD43A3",
    version="061",
    bounding_box="-51.0,66.0,-49.0,68.0",
)
```

These are not interchangeable. A `bounding_box`'s edges follow parallels and meridians,
while a `polygon`'s edges are great-circle arcs, so away from the equator a polygon
through the same four corners selects a smaller area.

## Collections

`collections` searches collection metadata and returns
`Vector{EarthData.Collections.UMM_C}`:

```julia
cc = collections(short_name="GEDI02_A")
first(cc).EntryTitle
first(cc).Abstract
```

## Request method

CMR searches use `POST` by default. Use `method=:GET` when compatibility with a
GET-only proxy or workflow is required:

```julia
gg = granules(short_name="GEDI02_A", method=:GET)
```
