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

### Geometries

The same parameters also accept an `Extents.Extent` or any GeoInterface geometry, so a
geometry you already have can be used directly:

```julia
using Extents

gg = granules(
    short_name="MCD43A3",
    version="061",
    bounding_box=Extent(X=(-51.0, -49.0), Y=(66.0, 68.0)),
)
```

Each parameter takes the geometry that matches it:

| parameter      | geometry                                  |
|:---------------|:------------------------------------------|
| `bounding_box` | `Extent`, or anything with an extent      |
| `point`        | point, or `(lon, lat)`                    |
| `line`         | line, line string                         |
| `polygon`      | polygon, linear ring                      |
| `circle`       | `(lon, lat, radius_m)`, `(point, radius)` |

CMR needs a `polygon` closed and wound counter-clockwise; both are handled for you, since
CMR reads a clockwise ring as everything *outside* it. CMR's `polygon` is a single ring, so
a polygon with holes is rejected rather than quietly searching the filled area.

Passing a vector of geometries searches their union, which is how CMR reads a repeated
spatial parameter:

```julia
gg = granules(short_name="MCD43A3", version="061", point=[(-50.0, 67.0), (-40.0, 60.0)])
```

Strings are still passed to CMR unchanged.

### Dates

The date-valued parameters — `temporal` among them — take a `Date` or `DateTime` as well as
the ISO 8601 string CMR expects, so the formatting is handled for you:

```julia
using Dates

gg = granules(short_name="GEDI02_A", temporal=Date(2019, 4, 18))
```

A tuple is a range, and either side may be `nothing` for an open bound:

```julia
granules(short_name="GEDI02_A", temporal=(Date(2019, 4, 18), Date(2019, 5, 1)))
granules(short_name="GEDI02_A", temporal=(Date(2019, 4, 18), nothing))   # everything since
granules(short_name="GEDI02_A", temporal=(nothing, Date(2019, 5, 1)))    # everything until
```

A `Date` is taken as midnight UTC and a `DateTime` as already being UTC, since CMR has no way
to read a local offset. Strings are passed through unchanged.

## Coverage of a result

A granule or collection states its own spatial coverage, and `Extents.extent` reads it back:

```julia
using Extents

g = first(granules(short_name="GEDI02_A"))
Extents.extent(g)  # Extent(X = (-105.27, -103.82), Y = (-2.09, -0.01))
```

The UMM geometry types implement GeoInterface, so a result's coverage is a geometry like any
other — it can go straight into `GeometryOps`, `Rasters.crop`, or another search:

```julia
gg = granules(short_name="MCD43A3", version="061", polygon=first(g.SpatialExtent.HorizontalSpatialDomain.Geometry.GPolygons))
```

Going the other way, an extent becomes a bounding rectangle, which is how coverage computed
elsewhere reaches a search:

```julia
rect = EarthData.Granules.BoundingRectangleType(Extents.extent(raster))
gg = granules(short_name="MCD43A3", version="061", bounding_box=rect)
```

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
