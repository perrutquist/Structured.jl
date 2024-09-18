"""
Wrapper type used for a workaround to https://github.com/quinnj/JSON3.jl/issues/272
until that issue is resolved.
"""
struct Workaround272{T} <: AbstractString
    str::T
end

JSON3.read_json_str(s::Workaround272) = s.str

"""
Parse a JSON string using `JSON3.read`, without first trying to interpret it as a filename.
"""
parse_json(s::AbstractString) = JSON3.read(Workaround272(s))
parse_json(s::AbstractString, t) = JSON3.read(Workaround272(s), t)
