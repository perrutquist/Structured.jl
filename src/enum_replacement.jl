"""
Option{I} <: AbstractString

An `Option` behaves similarly to an `Enum` in that it can take on a limited number of values, and it
will generate an identical JSON schema as the corresponding `Enum` type.

The type argument `I` must be a `Tuple` of `Symbol`s, and the value can only be one of those symbols.

Example:

`Option{(:yes, :no)}` is a type that can hold either of the values `:yes` or `:no`.

```
Option{(:yes, :no)}(:yes)   # ok
Option{(:yes, :no)}(:maybe) # error
```
"""
struct Option{T}
    s::Symbol
    function Option{T}(s::Symbol) where {T}
        T isa NTuple{N, Symbol} where N || error("Options list must be a tuple of symbols.")
        s in T || throw(ArgumentError(string(s, " is is not a valid option. Valid options are: ", T)))
        new{T}(s)
    end
end

Option{T}(x::Option{T}) where {T} = x
Option{T}(x::Option) where {T} = Option{T}(x.s)
Option{T}(x::AbstractString) where {T} = Option{T}(Symbol(x))

Base.Symbol(o::Option) = o.s
Base.string(o::Option) = string(o.s)
Base.:(==)(a::Symbol, b::Option) = a == b.s 
Base.:(==)(a::Option, b::Symbol) = a.s == b 

StructTypes.StructType(::Type{<:Option}) = StructTypes.StringType()

function Base.show(io::IO, o::Option{T}) where {T} 
    print(io, "Option{")
    show(io, T)
    print(io, "}(")
    show(io, o.s)
    print(io, ")")
end

function Base.instances(::Type{Option{T}}) where {T}
    Option{T}.(T)
end
