"""
    WithLogprobs{T}

A value of type T, along with the top tokens and their respective logprobs from the large language model.

This works by extracting the position of the value in the JSON string when read using the JSON3.jl package, 
so that the `set_logprobs!` function knows where to look.

Warning: Relies on the internals of JSON3.jl and might break in future versions of that package.
"""
struct WithTopLogprobs{T}
    value::T
    pos::Int
    top_logprobs::Vector{Pair{String, Float64}}
end

WithTopLogprobs(v, p) = WithTopLogprobs(v, p, Pair{String, Float64}[])

StructTypes.StructType(::Type{WithTopLogprobs{T}}) where {T} = StructTypes.StructType(T)

schema_and_subtypes(::Type{<:WithTopLogprobs{T}}) where {T} = schema_and_subtypes(T)

Base.convert(::Type{T}, o::WithTopLogprobs{T}) where {T} = o.value

function JSON3.read(i::StructTypes.StringType, buf, pos, len, b, ::Type{WithTopLogprobs{T}}; kw...) where {T}
    Char(buf[pos]) == '"' || error("Expected string to start with quotation mark.")
    next_pos, x = JSON3.read(i, buf, pos, len, b, T; kw...)
    next_pos, WithTopLogprobs(x, pos+1) # pos+1 because the first character of the string is the quotation mark
end

function JSON3.read(i::StructTypes.BoolType, buf, pos, len, b, ::Type{WithTopLogprobs{T}}; kw...) where {T}
    next_pos, x = JSON3.read(i, buf, pos, len, b, T; kw...)
    next_pos, WithTopLogprobs(x, pos)
end

function logprobs_at(logprobs, ix::Integer)
    #@show logprobs
    ix < 1 && throw(BoundsError("Index must be positive"))
    i = 1
    for lp in logprobs
        next_i = i + length(lp.bytes)
        if ix < next_i
            return (lp, ix - i + 1)
        end
        i = next_i
    end
    throw(throw(BoundsError(lazy"Index $ix is greater than the buffer length $i.")))
end

function find_logprobs!(_, o::WithTopLogprobs, logprobs)
    isempty(o.top_logprobs) || error("Logprobs have already been filled.")
    lp, offs = logprobs_at(logprobs, o.pos)
    offs == 1 || error("Value is not at a token boundary.") # TODO: Clip tokens?
    for t in lp.top_logprobs
        push!(o.top_logprobs, t.token => t.logprob)
    end
    o
end

find_logprobs!(o::T, logprobs) where {T} = find_logprobs!(StructTypes.StructType(T), o, logprobs)

find_logprobs!(_, o, _) = o

function find_logprobs!(::StructTypes.Struct, o::T, logprobs) where {T}
    for k in fieldnames(T)
        find_logprobs!(getfield(o, k), logprobs)
    end
    o
end

function find_logprobs!(::StructTypes.Array, o, logprobs)
    for x in o
        find_logprobs!(x, logprobs)
    end
    o
end

function _getfirst(f, list, default=nothing)
    ix = findfirst(f, list)
    ix isa Nothing && return default
    list[ix]
end

function _getlogprob(s, top_logprobs)
    last(_getfirst(p->startswith(first(p), string(s)), top_logprobs, -Inf))
end

function get_probability(o::WithTopLogprobs{OneOf{T}}, s::Symbol) where {T}
    s in T || throw(ArgumentError(lazy"$s, is not one of $T"))
    exp(_getlogprob(s, o.top_logprobs))
end 

get_probability(o::WithTopLogprobs{OneOf{T}}, s::OneOf{T}) where {T} = get_probability(o, Symbol(s))

function get_probability(o::WithTopLogprobs{OneOf{T}}) where {T}
    NamedTuple{T}(ntuple(i -> get_probability(o, T[i]), length(T)))
end 

function get_probability(o::WithTopLogprobs{Bool}, b::Bool) 
    exp(_getlogprob(b ? :true : :false, o.top_logprobs))
end 

function get_probability(o::WithTopLogprobs{Bool}) 
    (true => get_probability(o, true), false => get_probability(o, false))
end 
