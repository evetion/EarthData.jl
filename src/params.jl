"""
Types for CMR's boolean, numeric, track and text search parameters.

Each keyword takes the Julia type the parameter means, and the conversion happens here.

| keyword                        | accepts                        | sent to CMR as      |
|:-------------------------------|:-------------------------------|:--------------------|
| `downloadable`, `browsable`, … | `Bool`                         | `true` / `false`    |
| `cloud_cover`                  | `(min, max)`, either `nothing` | `min,max`           |
| `equator_crossing_longitude`   | `(min, max)`, either `nothing` | `min,max`           |
| `cycle`                        | positive `Integer`             | `1`                 |
| `passes`                       | `Int`, [`Pass`](@ref), vector  | `passes[0][pass]=1` |
| `version`, `short_name`, …     | `AbstractString` or `Symbol`   | the text as written |

A string passes through in every family, as the escape hatch for a value these types cannot
express — an open-ended range, a hand-written coordinate list, a boolean spelled `TRUE`.

Two different failures are being prevented. CMR *validates* the first four families and
answers a wrong value with an HTTP 400, so converting here turns a wasted round-trip into an
immediate error. The text parameters it does not validate at all — a value of the wrong
shape simply matches nothing — so there the type is what turns a silent empty result into an
error.

`version` is the sharpest case: collection versions are zero-padded, and `version=061` in
Julia is the integer `61`, which CMR answers with 0 hits instead of MCD43A3's 2.98 million.
Requiring a string means `version="061"` is the only thing that compiles.

Omitting a parameter is how you say "do not filter on it": CMR also accepts `unset` for a
boolean, but that returns exactly the unfiltered result set, so `nothing` covers it.
"""

# Booleans reject `1`, `0` and any other word: "Parameter downloadable must take value of
# true, false, or unset".
const bool_params = (
    :downloadable,
    :online_only,
    :browsable,
    :has_granules,
    :has_granules_or_cwic,
    :has_granules_or_opensearch,
    :has_opendap_url,
    :cloud_hosted,
    :standard_product,
    :all_revisions,
)

"""
    cmr_bool(param::Symbol, value)

Convert `value` into the string CMR expects for the boolean parameter `param`. Strings and
`nothing` pass through; anything that is not a `Bool` raises an `ArgumentError`.
"""
cmr_bool(::Symbol, value::Bool) = string(value)
cmr_bool(::Symbol, value::AbstractString) = String(value)
cmr_bool(::Symbol, ::Nothing) = nothing

cmr_bool(param::Symbol, value::AbstractVector) = [cmr_bool(param, v) for v in value]

# `1` is not a synonym for `true` here: CMR answers it with "Parameter downloadable must take
# value of true, false, or unset", so an `Integer` is a mistake rather than a value to convert.
cmr_bool(param::Symbol, value) = throw(
    ArgumentError(
        "`$(param)` takes `true` or `false`; got $(repr(value))::$(typeof(value)). " *
        "Omit the keyword to search without filtering on it.",
    ),
)

# Both are ranges rather than single values: CMR answers a lone number with "The min and max
# values of a numeric range cannot both be nil".
const numeric_range_params = (:cloud_cover, :equator_crossing_longitude)

const RangeBound = Union{Real,Nothing}

"""
    cmr_numeric_range(param::Symbol, value)

Convert `value` into the `min,max` string CMR expects for the numeric-range parameter
`param`. Either bound may be `nothing` for an open end; strings pass through.

CMR does not bound these to a percentage or a longitude, so neither does this — a range it
accepts is not narrowed here.
"""
cmr_numeric_range(::Symbol, value::AbstractString) = String(value)
cmr_numeric_range(::Symbol, ::Nothing) = nothing

cmr_numeric_range(param::Symbol, ::Tuple{Nothing,Nothing}) = throw(
    ArgumentError("`$(param)` needs at least one bound; both sides of the range are nothing."),
)

function cmr_numeric_range(param::Symbol, (lo, hi)::Tuple{RangeBound,RangeBound})
    isnothing(lo) ||
        isnothing(hi) ||
        lo <= hi ||
        throw(ArgumentError("`$(param)` range ends below where it starts: $(lo) to $(hi)."))
    return string(
        isnothing(lo) ? "" : coord_string(lo),
        ",",
        isnothing(hi) ? "" : coord_string(hi),
    )
end

cmr_numeric_range(param::Symbol, value::AbstractVector) =
    [cmr_numeric_range(param, v) for v in value]

# A single number is the one form CMR refuses, so name the range rather than pass it on.
cmr_numeric_range(param::Symbol, value::Real) = throw(
    ArgumentError(
        "`$(param)` takes a (min, max) range, not the single value $(value). Leave one side " *
        "`nothing` for an open end: ($(value), nothing) or (nothing, $(value)).",
    ),
)

cmr_numeric_range(param::Symbol, value) = throw(
    ArgumentError(
        "`$(param)` takes a (min, max) tuple of numbers with either side optionally " *
        "`nothing`; got $(typeof(value)).",
    ),
)

# `cycle` must be positive. `processing_level_id` is a level rather than a quantity, so it is
# not bounded that way — CMR carries "1B", "2G" and "NA" alongside the plain digits, and does
# not zero-pad ("01" matches nothing where "1" matches).
const positive_int_params = (:cycle,)

"""
    cmr_positive_int(param::Symbol, value)

Convert `value` into the string CMR expects for the positive-integer parameter `param`.
Strings pass through; a non-integer or a non-positive number raises an `ArgumentError`.
"""
cmr_positive_int(::Symbol, value::AbstractString) = String(value)
cmr_positive_int(::Symbol, ::Nothing) = nothing

function cmr_positive_int(param::Symbol, value::Integer)
    value > 0 ||
        throw(ArgumentError("`$(param)` must be a positive integer; got $(value)."))
    return string(value)
end

cmr_positive_int(param::Symbol, value::AbstractVector) =
    [cmr_positive_int(param, v) for v in value]

cmr_positive_int(param::Symbol, value) = throw(
    ArgumentError("`$(param)` must be a positive integer; got $(repr(value))."),
)

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
    cmr_passes(value) -> Vector{Pair{String,String}}

The `passes[N][pass]` and `passes[N][tiles]` parameters for `value`, which is a pass number,
a [`Pass`](@ref), or a vector of either.

CMR indexes each pass separately rather than repeating one key, so this returns the pairs
instead of a single value — which is why the query is a pair vector and not a `Dict`.
"""
cmr_passes(value) = cmr_passes([value])
cmr_passes(value::Pass) = cmr_passes([value])

function cmr_passes(values::AbstractVector)
    pairs = Pair{String,String}[]
    for (i, value) in enumerate(values)
        p = value isa Pass ? value : Pass(value)
        # CMR numbers the groups from zero.
        n = i - 1
        push!(pairs, "passes[$(n)][pass]" => string(p.pass))
        isempty(p.tiles) || push!(pairs, "passes[$(n)][tiles]" => join(p.tiles, ","))
    end
    return pairs
end

# A string is already the wire form, so it is passed through as the whole parameter.
cmr_passes(value::AbstractString) = ["passes" => String(value)]

# Every parameter below answers a value of the wrong shape with HTTP 200 and no matches, or
# with a 400 that a Julia type cannot pre-empt, so text is what it takes. Each was checked
# against the service.
#
# `processing_level_id` is deliberately absent: its values are the bare digits CMR stores
# ("2" matches 3715 collections), so a number is right there and rejecting one would be
# stricter than the service. So are the structured parameters — `attribute` and
# `science_keywords` need a nested key — and `variables`, which CMR does not recognize as a
# search parameter at all.
const text_params = (
    :archive_center,
    :author,
    :collection_concept_id,
    :collection_data_type,
    :concept_id,
    :consortium,
    :data_center,
    :day_night_flag,
    :doi,
    :echo_collection_id,
    :echo_granule_id,
    :entry_id,
    :entry_title,
    :granule_data_format,
    :granule_ur,
    :instrument,
    :keyword,
    :native_id,
    :platform,
    :project,
    :provider,
    :provider_short_name,
    :readable_granule_name,
    :sensor,
    :service_concept_id,
    :service_name,
    :service_type,
    :short_name,
    :sort_key,
    :spatial_keyword,
    :tag_key,
    :tool_concept_id,
    :tool_name,
    :tool_type,
    :two_d_coordinate_system,
    :two_d_coordinate_system_name,
    :variable_concept_id,
    :variable_name,
    :variable_native_id,
    :version,
)

"""
    cmr_text(param::Symbol, value)

Convert `value` into the string CMR expects for the text parameter `param`. A `Symbol` is
taken as its name, so `day_night_flag=:day` works; a number raises.

The values are identifiers, not quantities. CMR matches them literally and reports no error
for one that matches nothing, so a number here is a mistake that would otherwise show up as
an empty result rather than as a failure.
"""
cmr_text(::Symbol, value::AbstractString) = String(value)
cmr_text(::Symbol, value::Symbol) = String(value)
cmr_text(::Symbol, ::Nothing) = nothing

cmr_text(param::Symbol, value::AbstractVector) = [cmr_text(param, v) for v in value]

# Zero-padded identifiers are the common case — `version="061"`, `processing_level_id="2G"` —
# and an `Integer` cannot carry the padding: `061` is `61` in Julia, which matches nothing.
cmr_text(param::Symbol, value::Number) = throw(
    ArgumentError(
        "`$(param)` takes text, not the number $(value); pass it as a string. CMR matches " *
        "these literally and reports no error for a value that matches nothing, so a number " *
        "would come back as an empty result rather than as a failure. Check the padding " *
        "while you are there: identifiers are often zero-padded, and `$(value)` cannot " *
        "carry a leading zero — MCD43A3 is version \"061\", not \"$(value)\".",
    ),
)

cmr_text(param::Symbol, value) = throw(
    ArgumentError("`$(param)` takes a string or a `Symbol`; got $(typeof(value))."),
)

"""
    param_family(param::Symbol) -> ParamFamily

Which conversion `param` needs. One singleton per family, so [`cmr_pairs`](@ref) dispatches
rather than testing membership at each call.

Adding a parameter to a family means naming it in that family's tuple; adding a family means
a singleton, a `param_family` method and one `cmr_pairs` method.
"""
abstract type ParamFamily end
struct SpatialParam <: ParamFamily end
struct TemporalParam <: ParamFamily end
struct BoolParam <: ParamFamily end
struct NumericRangeParam <: ParamFamily end
struct PositiveIntParam <: ParamFamily end
struct PassesParam <: ParamFamily end
struct TextParam <: ParamFamily end
# Whatever this package does not describe — `attribute`'s triple, and any parameter CMR adds
# — is passed on as given, so a keyword stays usable before it is typed here.
struct FreeParam <: ParamFamily end

function param_family(param::Symbol)
    param === :passes && return PassesParam()
    param in spatial_params && return SpatialParam()
    param in temporal_params && return TemporalParam()
    param in bool_params && return BoolParam()
    param in numeric_range_params && return NumericRangeParam()
    param in positive_int_params && return PositiveIntParam()
    param in text_params && return TextParam()
    return FreeParam()
end

"""
    cmr_pairs(family, param::Symbol, value) -> Vector{Pair{String,Any}}

The query parameters `value` becomes for `param`. A family yields one pair, except
`passes`, which CMR indexes into several.
"""
cmr_pairs(::SpatialParam, param::Symbol, value) =
    [string(param) => cmr_spatial(param, value)]
cmr_pairs(::TemporalParam, param::Symbol, value) =
    [string(param) => cmr_temporal(param, value)]
cmr_pairs(::BoolParam, param::Symbol, value) = [string(param) => cmr_bool(param, value)]
cmr_pairs(::NumericRangeParam, param::Symbol, value) =
    [string(param) => cmr_numeric_range(param, value)]
cmr_pairs(::PositiveIntParam, param::Symbol, value) =
    [string(param) => cmr_positive_int(param, value)]
cmr_pairs(::PassesParam, ::Symbol, value) = cmr_passes(value)
cmr_pairs(::TextParam, param::Symbol, value) = [string(param) => cmr_text(param, value)]
cmr_pairs(::FreeParam, param::Symbol, value) = [string(param) => value]
