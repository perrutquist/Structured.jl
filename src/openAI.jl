@enum Role system user assistant

struct Message
    role::Role
    content::String
end

Base.:(=>)(r::Role, c::String) = Message(r, c) 

const default_model = "gpt-4o-2024-08-06"

function response_format(t, name=string(t))
    (type="json_schema", json_schema=(name=name, schema=schema(t), strict=true))
end

function get_choices(T, response)
    [_get_choice(T, c)::T for c in response.response.choices]
end

function _get_choice(T, c)
    c.finish_reason == "length" && error("JSON output not complete due to length limit.")
    c.finish_reason == "content_filter" && error("JSON output not complete due to content filter.")
    hasproperty(c.message, :refusal) && !isnothing(c.message.refusal) && error("Refused with message: ", c.message.refusal)
    JSON3.read(c.message.content, T)
end
