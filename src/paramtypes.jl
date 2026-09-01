"""
The Julia types CMR's search parameters accept, one per family.

These are the field types of [`GranuleRequest`](@ref) and [`CollectionRequest`](@ref), so a
parameter is named in exactly one place and its family follows from its declaration.
`params.jl` holds the conversion methods keyed on these types.

`Nothing` is in every one: omitting a parameter is how you search without filtering on it.
A `String` is in every one too, as the escape hatch for a value the other types cannot
express.
"""

# The bounds of a range are open on the side that is `nothing`, which CMR reads as an empty
# field.
const RangeBound = Union{Real,Nothing}
const TemporalBound = Union{Date,DateTime,Nothing}

"""
    TextParam

An identifier CMR matches literally: a `String`, a `Symbol`, or a vector of either.

CMR reports no error for a value that matches nothing, so a number is rejected rather than
converted — see `version`, where `061` is the integer `61` and matches nothing.
"""
const TextParam = Union{Nothing,String,Vector{String}}

"""
    BoolParam

A `Bool`, or a `String` for a spelling CMR takes but this module does not build (`"TRUE"`,
`"unset"`). CMR rejects `1` and `0`.
"""
const BoolParam = Union{Nothing,Bool,String}

"""
    NumericRangeParam

A `(min, max)` range, either side `nothing` for an open end. CMR refuses a lone number:
"The min and max values of a numeric range cannot both be nil".
"""
const NumericRangeParam =
    Union{Nothing,String,Tuple{RangeBound,RangeBound},Vector{Tuple{RangeBound,RangeBound}}}

"""
    PositiveIntParam

A positive `Integer`, or a vector of them.
"""
const PositiveIntParam = Union{Nothing,String,Int,Vector{Int}}

"""
    DateParam

A single `Date` or `DateTime`, in UTC. Distinct from [`DateRangeParam`](@ref): CMR answers a
range here with "updated_since datetime is invalid".
"""
const DateParam = Union{Nothing,String,Date,DateTime}

"""
    DateRangeParam

A `Date`/`DateTime`, or a `(start, stop)` range with either side `nothing` for an open bound.
"""
const DateRangeParam = Union{
    Nothing,
    String,
    Date,
    DateTime,
    Tuple{TemporalBound,TemporalBound},
    Vector{String},
}

"""
    Pass(pass::Integer, tiles=String[])

One orbital pass to search, optionally narrowed to particular tiles.

`pass` is a positive integer. A tile is an integer followed by `L`, `R` or `F` — the left,
right or full swath of that pass, as in `"2L"`. Tiles within one `Pass` are ANDed; several
`Pass`es are ORed.

Searching by pass needs the `cycle` keyword as well, since a pass number only identifies a
granule within a cycle.

```jldoctest
EarthData.Pass(1, ["1L", "2F"])
# output
EarthData.Pass(1, ["1L", "2F"])
```
"""
struct Pass
    pass::Int
    tiles::Vector{String}

    function Pass(pass::Integer, tiles=String[])
        pass > 0 ||
            throw(ArgumentError("A pass must be a positive integer; got $(pass)."))
        checked = String[]
        for tile in tiles
            s = String(tile)
            isnothing(match(r"^\d+[LRF]$", s)) && throw(
                ArgumentError(
                    "A tile is an integer followed by L, R or F, as in \"2L\"; got " *
                    "$(repr(s)).",
                ),
            )
            push!(checked, s)
        end
        return new(pass, checked)
    end
end

Base.:(==)(a::Pass, b::Pass) = a.pass == b.pass && a.tiles == b.tiles

"""
    PassesParam

An orbital pass: an `Integer`, a [`Pass`](@ref) to name its tiles, or a vector of either.
Needs exactly one `cycle` alongside.

Stored as a `Vector{Pass}` however it was written, since CMR indexes each pass separately and
one pass is the same shape as several.
"""
const PassesParam = Union{Nothing,String,Vector{Pass}}

"""
    SpatialParam

A geometry: an `Extents.Extent`, anything implementing GeoInterface, a coordinate tuple, or
the coordinate string itself.

All five spatial parameters accept the same Julia types, so unlike the other families this
one cannot be told apart by its field type — `bounding_box` and `polygon` are distinguished
by name in `spatial.jl`, against `spatial_params`.
"""
const SpatialParam = Any

"""
    FreeParam

A parameter this package does not describe, passed on as given.

Either it is structured in a way a Julia type does not capture (`attribute`,
`science_keywords`), or CMR is more permissive than any type would be
(`processing_level_id` holds the bare digits, so a number is right there).
"""
const FreeParam = Any
