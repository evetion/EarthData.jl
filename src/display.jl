Base.show(io::IO, x::AbstractJSON) = _show(io, x, true)
Base.show(io::IO, m::MIME"text/plain", x::AbstractJSON) = _show(io, x, false)

# A UMM record is its fields: two parsed from the same JSON describe the same thing, and a
# geometry built to answer a query should equal the one a record carries. Julia's default
# compares a struct holding a `Vector` by that vector's identity, so records with identical
# coordinates would otherwise differ. `hash` has to agree, or such records collide as `Dict`
# keys and `Set` fails to deduplicate them.
Base.:(==)(a::T, b::T) where {T<:AbstractJSON} =
    all(name -> getfield(a, name) == getfield(b, name), fieldnames(T))

Base.isequal(a::T, b::T) where {T<:AbstractJSON} =
    all(name -> isequal(getfield(a, name), getfield(b, name)), fieldnames(T))

function Base.hash(x::AbstractJSON, h::UInt)
    h = hash(typeof(x), h)
    for name in fieldnames(typeof(x))
        h = hash(getfield(x, name), h)
    end
    return h
end

nothingtype(::Type{Nothing}) = true
nothingtype(::Type{Union{Nothing,T}}) where {T} = true
nothingtype(x) = false

function _show(io, x, compact=false)
    T = typeof(x)
    print(io, T)
    if !(compact || get(io, :compact, false))
        for (k, v) in zip(fieldnames(T), fieldtypes(T))
            if !(nothingtype(v) && isnothing(getfield(x, k)))
                print(io, "\n\t$k")
            end
        end
    end
end
