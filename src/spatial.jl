"""
Geometry support for CMR's spatial search parameters.

CMR takes spatial constraints as comma-separated coordinate strings, always **longitude
first**. Those are easy to get subtly wrong by hand, so the spatial keywords also accept
geometries: an `Extents.Extent`, or anything implementing GeoInterface.

| keyword        | accepts                                   | sent to CMR as            |
|:---------------|:------------------------------------------|:--------------------------|
| `bounding_box` | `Extent`, rectangle                       | `west,south,east,north`   |
| `point`        | point, `(lon, lat)`                       | `lon,lat`                 |
| `line`         | line, line string                         | `lon1,lat1,lon2,lat2,…`   |
| `polygon`      | polygon, linear ring                      | closed counter-clockwise ring |
| `circle`       | `(lon, lat, radius_m)`, `(point, radius)` | `lon,lat,radius`          |

Strings pass through untouched, so existing calls are unaffected. A vector of geometries
becomes a repeated parameter, which CMR reads as their union.

Each keyword takes only the geometry that matches it. Reducing a polygon to its bounding box,
say, would search a larger area than was asked for, so a mismatch is an error that names the
right keyword instead.
"""

const spatial_params = (:bounding_box, :point, :line, :polygon, :circle)

# CMR wants plain decimal degrees, but `string(1e-5)` gives "1.0e-5", which it rejects. Nine
# decimals is well under a millimetre on the ground; trailing zeros are then trimmed off.
function coord_string(v::Real)
    x = float(v)
    isfinite(x) || throw(ArgumentError("Coordinate is not finite: $(v)"))
    s = rstrip(rstrip(Printf.@sprintf("%.9f", x), '0'), '.')
    return isempty(s) || s == "-" ? "0" : s
end

join_coords(coords) = join((coord_string(c) for c in coords), ",")

"""
    cmr_spatial(param::Symbol, value)

Convert `value` into the string CMR expects for the spatial parameter `param`. Strings and
`nothing` pass through; geometries are converted; anything else raises an `ArgumentError`
naming what `param` accepts.
"""
cmr_spatial(param::Symbol, value) = cmr_spatial(param, GeoInterface.trait(value), value)

cmr_spatial(::Symbol, value::AbstractString) = value
cmr_spatial(::Symbol, ::Nothing) = nothing

function cmr_spatial(param::Symbol, value::AbstractVector)
    # A vector of numbers is the coordinate list itself; a vector of anything else is a
    # repeated parameter.
    all(v -> v isa Real, value) && return join_coords(value)
    return [cmr_spatial(param, v) for v in value]
end

function cmr_spatial(param::Symbol, value::Tuple)
    # `circle` is the one parameter with no matching geometry, because a radius is not part of
    # any GeoInterface trait, so it takes a centre plus a radius in metres.
    if param === :circle
        length(value) == 2 && !(value[1] isa Real) && return circle_string(value...)
        length(value) == 3 || throw(
            ArgumentError(
                "`circle` takes (lon, lat, radius_m) or (point, radius_m); got " *
                "$(length(value)) values.",
            ),
        )
    elseif param === :point
        length(value) == 2 ||
            throw(ArgumentError("`point` takes (lon, lat); got $(length(value)) values."))
    end
    all(v -> v isa Real, value) || throw(
        ArgumentError("`$(param)` takes a tuple of numbers; got $(typeof(value))."),
    )
    return join_coords(value)
end

function circle_string(centre, radius::Real)
    GeoInterface.trait(centre) isa GeoInterface.PointTrait ||
        throw(ArgumentError("`circle` needs a point as its centre; got $(typeof(centre))."))
    return join_coords((GeoInterface.x(centre), GeoInterface.y(centre), radius))
end

# An `Extent` is a `RectangleTrait`, but only carries X and Y if it was built with them.
function cmr_spatial(param::Symbol, ::GeoInterface.RectangleTrait, value)
    wrong_param(param, :bounding_box, "a bounding box")
    ext = value isa Extents.Extent ? value : GeoInterface.extent(value)
    isnothing(ext) &&
        throw(ArgumentError("Cannot get an extent from $(typeof(value)) for `bounding_box`."))
    (haskey(ext, :X) && haskey(ext, :Y)) || throw(
        ArgumentError("`bounding_box` needs an extent with X and Y; got $(keys(ext))."),
    )
    x, y = ext.X, ext.Y
    return join_coords((x[1], y[1], x[2], y[2]))
end

function cmr_spatial(param::Symbol, ::GeoInterface.PointTrait, value)
    param === :circle && throw(
        ArgumentError(
            "`circle` also needs a radius in metres: pass (point, radius_m) or " *
            "(lon, lat, radius_m).",
        ),
    )
    wrong_param(param, :point, "a point")
    return join_coords((GeoInterface.x(value), GeoInterface.y(value)))
end

function cmr_spatial(
    param::Symbol,
    ::Union{GeoInterface.LineTrait,GeoInterface.LineStringTrait},
    value,
)
    wrong_param(param, :line, "a line")
    coords = Float64[]
    for p in GeoInterface.getpoint(value)
        push!(coords, GeoInterface.x(p), GeoInterface.y(p))
    end
    return join_coords(coords)
end

function cmr_spatial(param::Symbol, ::GeoInterface.LinearRingTrait, value)
    wrong_param(param, :polygon, "a ring")
    return join_coords(ring_coords(value))
end

function cmr_spatial(param::Symbol, ::GeoInterface.PolygonTrait, value)
    wrong_param(param, :polygon, "a polygon")
    # CMR's `polygon` is a single ring, so a hole cannot be expressed. Dropping it silently
    # would return granules the caller meant to exclude.
    nhole = GeoInterface.nhole(value)
    nhole == 0 || throw(
        ArgumentError(
            "CMR's `polygon` takes a single ring, but this polygon has $(nhole) hole(s), " *
            "which CMR cannot express.",
        ),
    )
    return join_coords(ring_coords(GeoInterface.getexterior(value)))
end

function cmr_spatial(param::Symbol, ::GeoInterface.MultiPolygonTrait, value)
    wrong_param(param, :polygon, "a multipolygon")
    n = GeoInterface.ngeom(value)
    n == 1 || throw(
        ArgumentError(
            "CMR's `polygon` takes one ring, but this multipolygon has $(n) polygons. Pass " *
            "a vector of polygons to search their union, or pick one.",
        ),
    )
    return cmr_spatial(param, GeoInterface.PolygonTrait(), GeoInterface.getgeom(value, 1))
end

function cmr_spatial(
    param::Symbol,
    ::Union{GeoInterface.MultiPointTrait,GeoInterface.MultiLineStringTrait},
    value,
)
    throw(
        ArgumentError(
            "`$(param)` takes one geometry. Pass a vector of geometries instead: CMR reads a " *
            "repeated spatial parameter as their union.",
        ),
    )
end

cmr_spatial(param::Symbol, trait, value) = throw(
    ArgumentError(
        "Cannot convert $(typeof(value)) ($(trait)) into CMR's `$(param)`. See " *
        "`EarthData.spatial_params`.",
    ),
)

cmr_spatial(param::Symbol, ::Nothing, value) = throw(
    ArgumentError(
        "`$(param)` takes a string, a tuple of coordinates, or a GeoInterface geometry; got " *
        "$(typeof(value)), which is none of those.",
    ),
)

function wrong_param(param::Symbol, expected::Symbol, what::AbstractString)
    param === expected ||
        throw(ArgumentError("`$(param)` does not take $(what); use `$(expected)`."))
    return nothing
end

"""
    ring_coords(ring) -> Vector{Float64}

Flatten a ring for CMR's `polygon`, which needs it **closed** and wound
**counter-clockwise**. Both are fixed here rather than asked of the caller: a clockwise ring
is a perfectly valid geometry, but CMR reads it as the complement, i.e. the whole globe
except the intended area, giving a wrong answer rather than an error.
"""
function ring_coords(ring)
    points = [(GeoInterface.x(p), GeoInterface.y(p)) for p in GeoInterface.getpoint(ring)]
    # Drop any closing point first, so winding and closure are independent of the input's.
    length(points) > 1 && first(points) == last(points) && pop!(points)
    length(points) >= 3 ||
        throw(ArgumentError("A polygon ring needs at least 3 points; got $(length(points))."))

    signed_area(points) < 0 && reverse!(points)
    push!(points, first(points))

    coords = Float64[]
    for (x, y) in points
        push!(coords, x, y)
    end
    return coords
end

# Twice the signed area (shoelace formula); positive means counter-clockwise. Only the sign is
# used, so neither the factor of two nor treating degrees as planar matters.
function signed_area(points)
    total = 0.0
    n = length(points)
    for i in 1:n
        x1, y1 = points[i]
        x2, y2 = points[i == n ? 1 : i + 1]
        total += x1 * y2 - x2 * y1
    end
    return total
end
