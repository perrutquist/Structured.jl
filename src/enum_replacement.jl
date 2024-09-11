"""
OneOf{I} <: AbstractString

An `OneOf` behaves similarly to an `Enum` in that it can take on a limited number of values, and it
will generate an identical JSON schema as the corresponding `Enum` type.

The type argument `I` must be a `Tuple` of `Symbol`s, and the value can only be one of those symbols.

Example:

`OneOf{(:yes, :no)}` is a type that can hold either of the values `:yes` or `:no`.

```
OneOf{(:yes, :no)}(:yes)   # ok
OneOf{(:yes, :no)}(:maybe) # error
```
"""
struct OneOf{T}
    s::Symbol
    function OneOf{T}(s::Symbol) where {T}
        T isa NTuple{N, Symbol} where N || error("OneOfs list must be a tuple of symbols.")
        s in T || throw(ArgumentError(string(s, " is is not a valid option. Valid options are: ", T)))
        new{T}(s)
    end
end

OneOf{T}(x::OneOf{T}) where {T} = x
OneOf{T}(x::OneOf) where {T} = OneOf{T}(x.s)
OneOf{T}(x::AbstractString) where {T} = OneOf{T}(Symbol(x))

Base.Symbol(o::OneOf) = o.s
Base.string(o::OneOf) = string(o.s)
Base.:(==)(a::Symbol, b::OneOf) = a == b.s 
Base.:(==)(a::OneOf, b::Symbol) = a.s == b 

StructTypes.StructType(::Type{<:OneOf}) = StructTypes.StringType()

function Base.show(io::IO, o::OneOf{T}) where {T} 
    print(io, "OneOf{")
    show(io, T)
    print(io, "}(")
    show(io, o.s)
    print(io, ")")
end

function Base.instances(::Type{OneOf{T}}) where {T}
    OneOf{T}.(T)
end
