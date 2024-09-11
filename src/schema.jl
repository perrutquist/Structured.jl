"""
    inlineschema(T)

Returns `true` if a schema for type `T` should be inline rather than a reference.
"""
inlineschema(::Type{T}) where {T} = inlineschema(StructTypes.StructType(T), T)
inlineschema(::Union) = true
inlineschema(::Type{Any}) = true

inlineschema(::StructTypes.StringType, _) = true
inlineschema(::StructTypes.NumberType, _) = true
inlineschema(::StructTypes.BoolType, _) = true
inlineschema(::StructTypes.NullType, _) = true
inlineschema(::StructTypes.DictType, _) = true
inlineschema(::StructTypes.UnorderedStruct, _) = false
inlineschema(::StructTypes.OrderedStruct, _) = false
inlineschema(::StructTypes.UnorderedStruct, ::Type{<:NamedTuple}) = true
inlineschema(::StructTypes.ArrayType, _) = true

"""
    (schema, subtypes) = schema_and_subtypes(T)

Returns a schema for type `T` and a list of types that are referenced from it.

The schema is in the form of a `NamedTuple` or `Pair` that will result in the correct
JSON schema when passed through the `JSON3.write` function.
    
If schemas are required for the fields or subtypes of `T` then those are either inlined 
in the returned schema, or the types are listed in the second output.
"""
function schema_and_subtypes(::Type{T}) where {T} 
    if isabstracttype(T)
        #return anyOf_and_subtypes(subtypes(T)) # requires InteractiveUtils
        throw(ArgumentError("Schemas of abstract types are not supported at the moment"))
    end
    schema_and_subtypes(StructTypes.StructType(T), T)
end

schema_and_subtypes(::Type{Any}) = ("\$comment" => "Any", [])
schema_and_subtypes(::Type{<:Pair}) = throw(ArgumentError("`Pair` is ambiguous. Use a `NamedTuple` instead."))
schema_and_subtypes(::Type{<:Ptr}) = throw(ArgumentError("`Ptr` has no schema. (Pointers are not supported by JSON.)"))

schema_and_subtypes(::StructTypes.StringType, _) = ((type="string",), [])
schema_and_subtypes(::Type{Symbol}) = ((type="string",), [])
schema_and_subtypes(::StructTypes.NumberType, ::Type{<:Real}) = ((type="number",), [])
schema_and_subtypes(::StructTypes.NumberType, ::Type{<:Integer}) = ((type="integer",), [])
schema_and_subtypes(::StructTypes.BoolType, _) = ((type="boolean",), [])
schema_and_subtypes(::StructTypes.NullType, _) = ((type="null",), [])

function schema_and_subtypes(::StructTypes.DictType, T)
    ET = valtype(T)
    if ET == Any
        ((type="object",), [])
    else
        if inlineschema(ET)
            s, st = schema_and_subtypes(ET)
            ((type="object", additionalProperties=s), st)
        else
            ((type="object", additionalProperties=schemaref(ET)), Any[ET,])
        end
    end
end

function schema_and_subtypes(::StructTypes.ArrayType, T)
    ET = eltype(T)
    if ET == Any
        ((type="array",), [])
    else
        if inlineschema(ET)
            s, st = schema_and_subtypes(ET)
            ((type="array", items=s), st)
        else
            ((type="array", items=schemaref(ET)), Any[ET,])
        end
    end
end

function schema_and_subtypes(::StructTypes.StringType, ::Type{T}) where {T<:Union{Enum, Option}}
    ((type="string", enum=Symbol.(instances(T))), [])
end

# Note: OpenAI's "Structured Output" API currently does not support
#       `minIems` so it may give invalid responses for `Tuple`
#       Therefore `NamedTuple` or `Vector` are better choices.
function schema_and_subtypes(::StructTypes.ArrayType, ::Type{T}) where {T<:Tuple}
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

function schema_and_subtypes(::Union{StructTypes.UnorderedStruct,StructTypes.OrderedStruct}, ::Type{T}) where {T}
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
