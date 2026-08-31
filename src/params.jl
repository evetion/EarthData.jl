"""
Conversion of CMR's search parameters, in two steps.

[`cmr_convert`](@ref) takes what the user wrote and normalizes it to the field type declared
in `requests.jl`, rejecting a value CMR would refuse or would silently answer with nothing.
[`cmr_pairs`](@ref) then turns a stored field into the query parameters that go on the wire.

Splitting them means a request holds the values it was written with — `temporal` stays a pair
of `Date`s — and the ISO 8601 and comma-separated coordinate spellings exist only at the edge.

| field type                                    | accepts                        | sent to CMR as      |
|:----------------------------------------------|:-------------------------------|:--------------------|
| [`BoolParam`](@ref)                           | `Bool`                         | `true` / `false`    |
| [`NumericRangeParam`](@ref)                   | `(min, max)`, either `nothing` | `min,max`           |
| [`PositiveIntParam`](@ref)                    | positive `Integer`             | `1`                 |
| [`PassesParam`](@ref)                         | `Int`, [`Pass`](@ref), vector  | `passes[0][pass]=1` |
| [`TextParam`](@ref)                           | `AbstractString` or `Symbol`   | the text as written |
| [`DateParam`](@ref), [`DateRangeParam`](@ref) | `Date`, `DateTime`, range      | ISO 8601 in UTC     |

A string passes through in every family, as the escape hatch for a value these types cannot
express — an open-ended range, a hand-written coordinate list, a boolean spelled `TRUE`.

Omitting a parameter is how you say "do not filter on it": CMR also accepts `unset` for a
boolean, but that returns exactly the unfiltered result set, so `nothing` covers it.
"""

"""
    cmr_convert(T::Type, value)

`value` as the field type `T`, or an `ArgumentError` describing what `T` accepts.

These methods describe the family only. [`convert_field`](@ref) adds the field name and its
docstring, which `Base.convert` has no way to see.
"""
cmr_convert(::Type{T}, value) where {T} = convert(T, value)

# A string is the escape hatch in every family, and `SubString` is not `String`, so
# converting to a `Union` that merely contains `String` would otherwise fail.
cmr_convert(::Type{T}, value::AbstractString) where {T} = String(value)

# Booleans reject `1`, `0` and every other word: "Parameter downloadable must take value of
# true, false, or unset". An `Integer` is a mistake rather than a value to convert, so the
# field type refusing it is the whole check.
cmr_convert(::Type{BoolParam}, value::Bool) = value

# Both numeric-range parameters are ranges rather than single values: CMR answers a lone
# number with "The min and max values of a numeric range cannot both be nil".
cmr_convert(::Type{NumericRangeParam}, ::Tuple{Nothing,Nothing}) = throw(
    ArgumentError("needs at least one bound; both sides of the range are nothing."),
)

function cmr_convert(::Type{NumericRangeParam}, (lo, hi)::Tuple{RangeBound,RangeBound})
    isnothing(lo) ||
        isnothing(hi) ||
        lo <= hi ||
        throw(ArgumentError("range ends below where it starts: $(lo) to $(hi)."))
    return (lo, hi)
end

# A single number is the one form CMR refuses, so name the range rather than pass it on.
cmr_convert(::Type{NumericRangeParam}, value::Real) = throw(
    ArgumentError(
        "takes a (min, max) range, not the single value $(value). Leave one side " *
        "`nothing` for an open end: ($(value), nothing) or (nothing, $(value)).",
    ),
)

cmr_convert(::Type{NumericRangeParam}, value::AbstractVector) =
    Tuple{RangeBound,RangeBound}[cmr_convert(NumericRangeParam, v) for v in value]

function cmr_convert(::Type{PositiveIntParam}, value::Integer)
    value > 0 || throw(ArgumentError("must be a positive integer; got $(value)."))
    return Int(value)
end

# CMR: "Cycle must be a positive integer, but was [1.5]".
cmr_convert(::Type{PositiveIntParam}, value::Real) =
    throw(ArgumentError("must be a positive integer; got $(value)."))

cmr_convert(::Type{PositiveIntParam}, value::AbstractVector) =
    Int[cmr_convert(PositiveIntParam, v) for v in value]

# Always a vector, so one pass and several are stored and sent the same way.
cmr_convert(::Type{PassesParam}, value::Integer) = [Pass(value)]
cmr_convert(::Type{PassesParam}, value::Pass) = [value]
cmr_convert(::Type{PassesParam}, value::AbstractVector) =
    Pass[v isa Pass ? v : Pass(v) for v in value]

# The text values are identifiers, not quantities. CMR matches them literally and reports no
# error for one that matches nothing. A `Symbol` is a reasonable way to write a fixed
# vocabulary, so `day_night_flag=:day` works.
cmr_convert(::Type{TextParam}, value::Symbol) = String(value)
cmr_convert(::Type{TextParam}, value::AbstractVector) =
    String[cmr_convert(TextParam, v) for v in value]

# Zero-padded identifiers are the common case — `version="061"` — and an `Integer` cannot
# carry the padding: `061` is `61` in Julia, which matches nothing.
cmr_convert(::Type{TextParam}, value::Number) = throw(
    ArgumentError(
        "takes text, not the number $(value); pass it as a string. CMR matches these " *
        "literally and reports no error for a value that matches nothing, so a number " *
        "comes back as an empty result rather than as a failure.",
    ),
)

"""
    cmr_pairs(param::Symbol, value) -> Vector{Pair{String,Any}}

The query parameters `value` becomes for `param`, dispatching on the stored field type.

A pair vector rather than one value, because `passes` becomes several indexed parameters
(`passes[0][pass]`, `passes[0][tiles]`, …) where every other family becomes one.
"""
cmr_pairs(param::Symbol, value) = Pair{String,Any}[string(param) => value]
cmr_pairs(param::Symbol, value::Bool) = Pair{String,Any}[string(param) => string(value)]
cmr_pairs(param::Symbol, value::Integer) = Pair{String,Any}[string(param) => string(value)]
cmr_pairs(param::Symbol, value::Union{Date,DateTime}) =
    Pair{String,Any}[string(param) => cmr_datetime(value)]

cmr_pairs(param::Symbol, value::Tuple{RangeBound,RangeBound}) =
    Pair{String,Any}[string(param) => range_string(value, coord_string)]
cmr_pairs(param::Symbol, value::Tuple{TemporalBound,TemporalBound}) =
    Pair{String,Any}[string(param) => range_string(value, cmr_datetime)]

# CMR reads a repeated parameter as the union of its values.
cmr_pairs(param::Symbol, values::AbstractVector) =
    reduce(vcat, (cmr_pairs(param, v) for v in values); init=Pair{String,Any}[])

function cmr_pairs(param::Symbol, passes::AbstractVector{Pass})
    pairs = Pair{String,Any}[]
    for (i, pass) in enumerate(passes)
        # CMR numbers the groups from zero.
        n = i - 1
        push!(pairs, "passes[$(n)][pass]" => string(pass.pass))
        isempty(pass.tiles) ||
            push!(pairs, "passes[$(n)][tiles]" => join(pass.tiles, ","))
    end
    return pairs
end

cmr_pairs(param::Symbol, pass::Pass) = cmr_pairs(param, [pass])

# An open bound is an empty field on its side of the comma.
range_string((lo, hi), tostring) =
    string(isnothing(lo) ? "" : tostring(lo), ",", isnothing(hi) ? "" : tostring(hi))

# Each family is read off the field types rather than listed a second time. The spatial
# parameters share one field type, so they keep their own list in `spatial.jl`.
const bool_params = param_names(BoolParam)
const numeric_range_params = param_names(NumericRangeParam)
const positive_int_params = param_names(PositiveIntParam)
const text_params = param_names(TextParam)
const range_date_params = param_names(DateRangeParam)
const instant_date_params = param_names(DateParam)
const temporal_params = (range_date_params..., instant_date_params...)
