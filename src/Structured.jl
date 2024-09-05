module Structured

using JSON

"""
Returns true if a schema should never be given as a reference
"""
inlineschema(::Type{T}) where {T} = false
inlineschema(::Type{String}) = true
inlineschema(::Type{Symbol}) = true
inlineschema(::Type{<:Real}) = true
inlineschema(::Type{Nothing}) = true
inlineschema(::Union) = true
inlineschema(::NamedTuple) = true

"""
Returns a schema and a list of types that are referenced from it
"""
schema_and_subtypes(::Type{String}) = ((type="string",), ())
schema_and_subtypes(::Type{Symbol}) = ((type="string",), ())
schema_and_subtypes(::Type{<:Real}) = ((type="number",), ())
schema_and_subtypes(::Type{<:Integer}) = ((type="integer",), ())
schema_and_subtypes(::Type{Bool}) = ((type="boolean",), ())
schema_and_subtypes(::Type{Nothing}) = ((type="null",), ())

function schema_and_subtypes(::Type{Vector{T}}) where {T}
    if inlineschema(T)
        s, st = schema_and_subtypes(t)
        ((type="array", items=s), st)
    else
        ((type="array", items=schemaref(T)), (T,))
    end
end

function schema_and_subtypes(::Type{T}) where {T<:Enum}
    ((type="string", enum=Symbol.(instances(T))), ())
end

# Note: OpenAI's "Structured Output" API currently does not support
#       `minIems` so it may give invalid responses for `Tuple`
#       Therefore `NamedTuple` or `Vector` might be better choices.
function schema_and_subtypes(::Type{T}) where {T<:Tuple}
    rt = []
    pr = []

    for v in T.types
        if inlineschema(v)
            s, st = schema_and_subtypes(v)
            for q in st
                _setpush!(rt, q)
            end
        else
            s = schemaref(v)
            _setpush!(rt, v)
        end
        push!(pr, s)
    end

    ((type="array", prefix_items=pr, items=false, minItems=lenght(v), maxItems=length(v)), (rt))
end

_setpush!(v, x) = x in v ? v : push!(v, x)

function schema_and_subtypes(::Type{T}) where {T}
    rt = []
    pr = []

    for (k,v) in zip(fieldnames(T), T.types)
        if inlineschema(v)
            s, st = schema_and_subtypes(v)
            for q in st
                _setpush!(rt, q)
            end
        else
            s = schemaref(v)
            _setpush!(rt, v)
        end
        push!(pr, k => s)
    end
    props = NamedTuple(pr) 
    ((type="object", properties=props, additionalProperties=false, required=keys(props)), Tuple(rt))
end

function schema_and_subtypes(T::Union)
    (; a, b) = T
    ts = [a]
    while b isa Union
        (; a, b) = b
        pushfirst!(ts, a)
    end
    pushfirst!(ts, b)
    a = []
    b = []
    for t in ts
        if inlineschema(t)
            ss, st = schema_and_subtypes(t)
            push!(a, ss)
            for q in st
                _setpush!(b, q)
            end
        else
            push!(a, schemaref(t))
            push!(b, t)
        end
    end

    ((anyOf=unique(a),), Tuple(b))
end

function schemaref(T)
    NamedTuple{(Symbol("\$ref"),)}((string("#/\$defs/", T),))
end

"""
A schema including a set of references with schemas.
"""
function schema(t)
    s, ts = schema_and_subtypes(t)
    isempty(ts) && return s
    i = 1
    ss = []
    while i<=length(ts)
        (si, tsi) = schema_and_subtypes(ts[i])
        push!(ss, Symbol(string(ts[i])) => si)
        for q in tsi
            _setpush!(ts, q)
        end
        i += 1
    end
    NamedTuple{(fieldnames(typeof(s))..., Symbol("\$defs"))}((s..., NamedTuple(ss)))
end

"""
Convert to a type, similar to `convert`, but attempts to re-create structs from `Dict`,
under the assumption that the struct has a default constructor that simply takes
each field in the order that they appear in the struct (i.e. the defult constructor). 

(Types that do not satisfy this requirement need their own `to_type` method.)
"""
to_type(::Type{T}, x) where {T} = convert(T, x)
to_type(::Type{T}, x::T) where {T} = x
to_type(::Type{Vector{T}}, v::Vector) where {T} = to_type.(T, v)

function to_type(::Type{T}, d::Dict{String}) where {T}
    fn = fieldnames(T)
    ft = T.types
    T(ntuple(i -> to_type(ft[i], d[string(fn[i])]), length(fn))...)
end

function to_type(::Type{T}, d::Union{NamedTuple, Dict{Symbol}}) where {T}
    fn = fieldnames(T)
    ft = T.types
    T(ntuple(i -> to_type(ft[i], d[fn[i]]), length(fn))...)
end

end # module