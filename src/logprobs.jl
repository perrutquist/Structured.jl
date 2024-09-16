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

Base.convert(::Type{T}, o::WithTopLogprobs{T}) where {T} = o.value

function JSON3.read(i::StructTypes.StringType, buf, pos, len, b, ::Type{WithTopLogprobs{T}}; kw...) where {T}
    @show i buf pos len b T
    next_pos, x = JSON3.read(i, buf, pos, len, b, T; kw...)
    next_pos, WithTopLogprobs(x, pos+1) # pos+1 to get one-based indexing
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

function find_logprobs!(::StructTypes.Array, o, logprobs) where {T}
    for x in o
        find_logprobs!(x, logprobs)
    end
    o
end
