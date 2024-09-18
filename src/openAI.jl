"""
Role

An `Enum` that deines the roles used by ChatGPT.
"""
@enum Role system user assistant

"""
Message

A type with a layout such that a `Vector{Message}` turns into the correct JSON for ChatGPT.

The `=>` operator can be used to construct a `Message`. 

For example: `system => "You are a helpful assistant."`
"""
struct Message
    role::Role
    content::String
end

Base.:(=>)(r::Role, c::String) = Message(r, c) 

const default_model = "gpt-4o-2024-08-06"

struct ResponseFormat{T} 
    type::String
    json_schema::T
end

"""
    response_format(T)

Calls `schema(T)` to obtain a JSON schema for Julia type `T`, and wraps it
in a `ResponseFormat` object that is designed to be passed as the `response_format` 
keyword argument of the `OpenAI.create_chat` function.

Note: When using the response_format keyword argument the AI must also be instructed
to output JSON. See the OpenAI API documentation on Structured Outputs.
"""
function response_format(t, name=schemaname(t))
    ResponseFormat("json_schema", (name=name, schema=schema(t), strict=true))
end

"""
    get_choices(T, response)

Extract, as type `T`, the replies from the `response` from the `OpenAI.create_chat` function.

Assumes that `create_chat` was called with the keyword argument `response_format = response_format(T)`.

Tip: If `create_chat` was called with `n = 1` (the default), then get_choice(T, response) can be used
as a shorthand for only(get_choices(T, response)).
"""
function get_choices(T, response)
    [_get_choice(T, c)::T for c in response.response.choices]
end
get_choices(T) = Base.Fix1(get_choices, T)

function _get_choice(T, c)
    c.finish_reason == "length" && error("JSON output not complete due to length limit.")
    c.finish_reason == "content_filter" && error("JSON output not complete due to content filter.")
    hasproperty(c.message, :refusal) && !isnothing(c.message.refusal) && error("Refused with message: ", c.message.refusal)
    o = parse_json(c.message.content, T)
    if hasproperty(c, :logprobs)
        find_logprobs!(o, c.logprobs.content)
    else
        o
    end
end

"""
    get_choice(T, response)

Equivalent to `only(get_choices(T, response))`.
"""
get_choice(T, response) = _get_choice(T, only(response.response.choices))
get_choice(T) = Base.Fix1(get_choice, T)
