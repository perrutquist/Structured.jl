module Structured

using JSON

"""
Returns true if a schema should never be given as a reference
"""
inlineschema(::Type{T}) where {T} = false
inlineschema(::Type{String}) = true
inlineschema(::Type{<:Real}) = true
inlineschema(::Type{Nothing}) = true
inlineschema(::Union) = true
inlineschema(::NamedTuple) = true

"""
Returns a schema and a list of types that are referenced from it
"""
schema(::Type{String}) = ((type="string",), ())
schema(::Type{<:Real}) = ((type="number",), ())
schema(::Type{<:Integer}) = ((type="integer",), ())
schema(::Type{Bool}) = ((type="boolean",), ())
schema(::Type{Nothing}) = ((type="null",), ())

function schema(::Type{Vector{T}}) where {T}
    if inlineschema(T)
        s, st = schema(t)
        ((type="array", items=s), st)
    else
        ((type="array", items=schemaref(T)), (T,))
    end
end

_setpush!(v, x) = x in v ? v : push!(v, x)

function schema(::Type{T}) where {T}
    rt = []
    pr = []

    for (k,v) in zip(fieldnames(T), T.types)
        if inlineschema(v)
            s, st = schema(v)
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
    ((type="object", properties=props, required=keys(props), additionalProperties=false), Tuple(rt))
end

function schema(T::Union)
    (; a, b) = T
    ts = [a]
    while b isa Union
        (; a, b) = b
        push!(ts, a)
    end
    push!(ts, b)
    a = []
    b = []
    for t in ts
        if inlineschema(t)
            ss, st = schema(t)
            push!(a, ss)
            for q in st
                _setpush!(b, q)
            end
        else
            push!(a, schemaref(t))
            push!(b, t)
        end
    end

    ((anyOf=a,), Tuple(b))
end

function schemaref(T)
    NamedTuple{(Symbol("\$ref"),)}((string("#/\$defs/", T),))
end

"""
A schema including a set of references with schemas.
"""
function schema_with_refs()
    # TODO
end

end # module