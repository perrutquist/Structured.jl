"""
Convert to a type, similar to `convert`, but attempts to re-create structs from `Dict{String}`,
under the assumption that the struct has a default constructor that simply takes
each field in the order that they appear in the struct (i.e. the defult constructor). 
(Types that do not satisfy this requirement need their own `to_type` method.)

Note: Parsing to a type union can be ambiguous, if the unioned types have the same field names.
Such constructs should be avoided.
"""
to_type(::Type{T}, x) where {T} = convert(T, x)
to_type(::Type{T}, x::T) where {T} = x
to_type(::Type{T}, x::Dict{String}) where {T<:Dict{String}} = T(x)
to_type(::Type{Symbol}, x::String) = Symbol(x)
to_type(::Type{Vector{T}}, v::Vector) where {T} = T[to_type(T, x) for x in v]

function to_type(::Type{T}, x::String) where {T<:Enum}
    for i in instances(T) # TODO: Currently, T cannot be a Union of Enums
        if string(i) == x
            return i 
        end
    end
    error("String $x does not match any instance of the Enum $T.")
end

function to_type(::Type{T}, d::Dict{String}) where {T}
    fn = fieldnames(T)
    ft = T.types
    T(ntuple(i -> to_type(ft[i], d[string(fn[i])]), length(fn))...)
end

function to_type(::Type{T}, d::Dict{String}) where {T <: NamedTuple}
    fn = fieldnames(T)
    ft = T.types
    T(ntuple(i -> to_type(ft[i], d[string(fn[i])]), length(fn)))
end

function to_type(U::Union, d::Dict{String})
    ts = _u2ts(U)
    for t in ts 
        # Try each type and return the first that fits
        t <: Union{String, Symbol, Real, Enum, Nothing} && continue # not represented as Dict
        if Set(string.(fieldnames(t))) == Set(keys(d))
            y = try 
                to_type(t, d)
            catch
                missing
            end
            !ismissing(y) && return y
        end
    end
    error("No matching type found in Union.")
end
