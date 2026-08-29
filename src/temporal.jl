"""
Date support for CMR's temporal search parameters.

CMR takes a temporal constraint as ISO 8601 in UTC, either a single instant or a
comma-separated `start,end` range with either side optionally empty for an open bound.
Writing those by hand is easy to get subtly wrong, so the temporal keywords also accept
dates, in any of the forms below.

| value                                | sent to CMR as                              |
|:-------------------------------------|:--------------------------------------------|
| `Date(2019, 4, 18)`                  | `2019-04-18T00:00:00Z`                      |
| `DateTime(2019, 4, 18, 6)`           | `2019-04-18T06:00:00Z`                      |
| `(Date(2019, 4, 18), Date(2019, 5))` | `2019-04-18T00:00:00Z,2019-05-01T00:00:00Z` |
| `(Date(2019, 4, 18), nothing)`       | `2019-04-18T00:00:00Z,`                     |
| `(nothing, Date(2019, 5))`           | `,2019-05-01T00:00:00Z`                     |

Strings pass through untouched, so existing calls are unaffected. A vector becomes a
repeated parameter, which CMR reads as the union.
"""

# CMR takes a range for most of the date parameters but a single instant for
# `updated_since`, which answers a range with "updated_since datetime is invalid".
const range_date_params = (
    :temporal,
    :created_at,
    :revision_date,
    :production_date,
    :equator_crossing_date,
    :has_granules_created_at,
    :has_granules_revised_at,
)

const instant_date_params = (:updated_since,)

const temporal_params = (range_date_params..., instant_date_params...)

# CMR wants UTC with a `Z`. A `Date` is midnight; a `DateTime` is taken as already UTC,
# since CMR has no way to read a local offset. `Dates.ISODateTimeFormat` is not a
# substitute: it emits fractional seconds. `Dates.format` needs the `DateTime`, since it
# has no `hour` for a `Date`.
cmr_datetime(d::Union{Date,DateTime}) =
    Dates.format(DateTime(d), dateformat"yyyy-mm-dd\THH:MM:SS\Z")

"""
    cmr_temporal(param::Symbol, value)

Convert `value` into the string CMR expects for the temporal parameter `param`. Strings and
`nothing` pass through; dates are converted; anything else raises an `ArgumentError` naming
what `param` accepts.
"""
cmr_temporal(::Symbol, value::AbstractString) = value
cmr_temporal(::Symbol, ::Nothing) = nothing

cmr_temporal(::Symbol, value::Union{Date,DateTime}) = cmr_datetime(value)

# A range. Either side may be `nothing` for an open bound, which CMR reads as an empty field.
const TemporalBound = Union{Date,DateTime,Nothing}

cmr_temporal(param::Symbol, ::Tuple{Nothing,Nothing}) = throw(
    ArgumentError("`$(param)` needs at least one bound; both sides of the range are nothing."),
)

function cmr_temporal(param::Symbol, (start, stop)::Tuple{TemporalBound,TemporalBound})
    param in instant_date_params && throw(
        ArgumentError(
            "`$(param)` takes a single date, not a range; CMR reads it as \"revised since\" " *
            "and rejects a pair. Use `revision_date` for a range.",
        ),
    )
    isnothing(start) ||
        isnothing(stop) ||
        DateTime(start) <= DateTime(stop) ||
        throw(ArgumentError("`$(param)` range ends before it starts: $(start) to $(stop)."))
    return string(
        isnothing(start) ? "" : cmr_datetime(start),
        ",",
        isnothing(stop) ? "" : cmr_datetime(stop),
    )
end

# A vector of dates is a repeated parameter, which CMR reads as the union.
cmr_temporal(param::Symbol, value::AbstractVector) = [cmr_temporal(param, v) for v in value]

# A range of dates is an `AbstractVector`, so it would otherwise become one clause per
# element — 121 of them for `Date(2019,1,1):Day(1):Date(2019,5,1)`. Its endpoints are what a
# caller means, so ask for those rather than silently sending the union.
cmr_temporal(param::Symbol, value::AbstractRange{<:Union{Date,DateTime}}) = throw(
    ArgumentError(
        "`$(param)` does not take a range; pass its endpoints as a tuple: " *
        "($(first(value)), $(last(value))).",
    ),
)

cmr_temporal(param::Symbol, value) = throw(
    ArgumentError(
        "`$(param)` takes a string, a `Date`/`DateTime`, or a (start, stop) tuple of those " *
        "with either side optionally `nothing`; got $(typeof(value)).",
    ),
)
