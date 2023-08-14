Base.show(io::IO, x::AbstractJSON) = _show(io, x, true)
Base.show(io::IO, m::MIME"text/plain", x::AbstractJSON) = _show(io, x, false)

nothingtype(::Type{Nothing}) = true
nothingtype(::Type{Union{Nothing,T}}) where {T} = true
nothingtype(x) = false

function _show(io, x, compact = false)
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
