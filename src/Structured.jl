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
schema_and_subtypes(::Type{String}) = ((type="string",), ())
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

    ((anyOf=a,), Tuple(b))
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

end # module