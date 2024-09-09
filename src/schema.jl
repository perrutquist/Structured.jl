"""
    inlineschema(T)

Returns `true` if a schema for type `T` should be inline rather than a reference.
"""
inlineschema(::Type{T}) where {T} = false
inlineschema(::Type{<:AbstractString}) = true
inlineschema(::Type{Symbol}) = true
inlineschema(::Type{Char}) = true
inlineschema(::Type{<:Real}) = true
inlineschema(::Type{Nothing}) = true
inlineschema(::Union) = true
inlineschema(::Type{<:NamedTuple}) = true
inlineschema(::Type{<:Dict}) = true
inlineschema(::Type{Any}) = true

"""
    (schema, subtypes) = schema_and_subtypes(T)

Returns a schema for type `T` and a list of types that are referenced from it.

The schema is in the form of a `NamedTuple` or `Pair` that will result in the correct
JSON schema when passed through the `JSON3.write` function.
    
If schemas are required for the fields or subtypes of `T` then those are either inlined 
in the returned schema, or the types are listed in the second output.
"""
schema_and_subtypes(::Type{String}) = ((type="string",), [])
schema_and_subtypes(::Type{Symbol}) = ((type="string",), [])
schema_and_subtypes(::Type{<:Real}) = ((type="number",), [])
schema_and_subtypes(::Type{<:Integer}) = ((type="integer",), [])
schema_and_subtypes(::Type{Bool}) = ((type="boolean",), [])
schema_and_subtypes(::Type{Nothing}) = ((type="null",), [])
schema_and_subtypes(::Type{<:Pair}) = throw(ArgumentError("`Pair` is ambiguous. Use a `NamedTuple` instead."))
schema_and_subtypes(::Type{<:Ptr}) = throw(ArgumentError("`Ptr` has no schema. (Pointers are not supported by JSON.)"))
schema_and_subtypes(::Type{Any}) = ("\$comment" => "Any", [])

# Note: OpenAI's "Structured Output" API currently does not support
#       `minLength` and `maxLength` so it may give invalid responses for `Char`
#       Therefore `String` might be a better choice.
schema_and_subtypes(::Type{Char}) = ((type="string",), [])

function schema_and_subtypes(::Type{<:Dict{<:Union{String, Symbol}, T}}) where {T}
    s, st = schema_and_subtypes(T)
    ((type="object", additionalProperties=s), st)
end

schema_and_subtypes(::Type{Dict{<:Union{String, Symbol}, Any}}) = ((type="object",), [])

function schema_and_subtypes(::Type{Vector{T}}) where {T}
    if inlineschema(T)
        s, st = schema_and_subtypes(T)
        ((type="array", items=s), st)
    else
        ((type="array", items=schemaref(T)), Any[T,])
    end
end

schema_and_subtypes(::Type{Vector{Any}}) = ((type="array",), [])

function schema_and_subtypes(::Type{T}) where {T<:Union{Enum, Option}}
    ((type="string", enum=Symbol.(instances(T))), [])
end

# Note: OpenAI's "Structured Output" API currently does not support
#       `minIems` so it may give invalid responses for `Tuple`
#       Therefore `NamedTuple` or `Vector` are better choices.
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

    ((type="array", prefix_items=pr, items=false, minItems=lenght(v), maxItems=length(v)), rt)
end

_setpush!(v, x) = x in v ? v : push!(v, x)

# The general case: Everything that is not an abstract type is treated as a struct
function schema_and_subtypes(::Type{T}) where {T}
    if isabstracttype(T)
        #return anyOf_and_subtypes(subtypes(T)) # requires InteractiveUtils
        throw(ArgumentError("Schemas of abstract types are not supported at the moment"))
    end
 
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
    ((type="object", properties=props, additionalProperties=false, required=keys(props)), rt)
end

function schema_and_subtypes(U::Union)
    (; a, b) = U
    ts = [a]
    while b isa Union
        (; a, b) = b
        pushfirst!(ts, a)
    end
    pushfirst!(ts, b)
    anyOf_and_subtypes(ts)
end

function anyOf_and_subtypes(ts)
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

    ((anyOf=unique(a),), b)
end

function schemaref(T)
    NamedTuple{(Symbol("\$ref"),)}((string("#/\$defs/", T),))
end

"""
    schema(T)

Returns a schema for type `T`, possibly including a set of references with schemas.

The schema is in the form of a `NamedTuple` that will result in the correct
JSON schema when passed through the `JSON3.write` function.

Note: Not all Julia types are supported, nor are the all schemas for supported types 
one-to-one matches. It is possible that a JSON object matching the schema still does
not parse into as type `T`.
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
