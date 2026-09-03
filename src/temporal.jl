"""
Date support for CMR's temporal search parameters.

CMR takes a temporal constraint as ISO 8601 in UTC, either a single instant or a
comma-separated `start,end` range with either side optionally empty for an open bound.
Writing those by hand is easy to get subtly wrong, so the temporal keywords take dates
instead, in any of the forms below.

| value                                | sent to CMR as                              |
|:-------------------------------------|:--------------------------------------------|
| `Date(2019, 4, 18)`                  | `2019-04-18T00:00:00Z`                      |
| `DateTime(2019, 4, 18, 6)`           | `2019-04-18T06:00:00Z`                      |
| `(Date(2019, 4, 18), Date(2019, 5))` | `2019-04-18T00:00:00Z,2019-05-01T00:00:00Z` |
| `(Date(2019, 4, 18), nothing)`       | `2019-04-18T00:00:00Z,`                     |
| `(nothing, Date(2019, 5))`           | `,2019-05-01T00:00:00Z`                     |

Strings pass through untouched. A vector becomes a repeated parameter, which CMR reads as the
union.

A range belongs to [`DateRangeParam`](@ref) and a single instant to [`DateParam`](@ref), so
`updated_since=(a, b)` is a `MethodError` from the field type rather than a check here — CMR
answers a range there with "updated_since datetime is invalid".
"""

# CMR wants UTC with a `Z`. A `Date` is midnight; a `DateTime` is taken as already UTC,
# since CMR has no way to read a local offset. `Dates.ISODateTimeFormat` is not a
# substitute: it emits fractional seconds. `Dates.format` needs the `DateTime`, since it
# has no `hour` for a `Date`.
cmr_datetime(d::Union{Date,DateTime}) =
    Dates.format(DateTime(d), dateformat"yyyy-mm-dd\THH:MM:SS\Z")

cmr_convert(::Type{DateRangeParam}, ::Tuple{Nothing,Nothing}) = throw(
    ArgumentError("needs at least one bound; both sides of the range are nothing."),
)

function cmr_convert(
    ::Type{DateRangeParam},
    (start, stop)::Tuple{TemporalBound,TemporalBound},
)
    isnothing(start) ||
        isnothing(stop) ||
        DateTime(start) <= DateTime(stop) ||
        throw(ArgumentError("range ends before it starts: $(start) to $(stop)."))
    return (start, stop)
end

# A vector is a repeated parameter, which CMR reads as the union. Each element converts as a
# single constraint would, so a vector takes the instants, ranges and strings a scalar does.
cmr_convert(::Type{DateRangeParam}, value::AbstractVector) =
    DateRangeValue[cmr_convert(DateRangeParam, v) for v in value]

# A `StepRange` of dates is an `AbstractVector`, so it would otherwise become one clause per
# element — 121 of them for `Date(2019,1,1):Day(1):Date(2019,5,1)`. Its endpoints are what a
# caller means, so ask for those rather than silently sending the union.
cmr_convert(::Type{DateRangeParam}, value::AbstractRange{<:Union{Date,DateTime}}) = throw(
    ArgumentError(
        "does not take a range of dates; pass its endpoints as a tuple: " *
        "($(first(value)), $(last(value))).",
    ),
)
