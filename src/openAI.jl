@enum Role system user assistant

struct Message
    role::Role
    content::String
end

Base.:(=>)(r::Role, c::String) = Message(r, c) 

const default_model = "gpt-4o-2024-08-06"

function response_format(t, name="response")
    (type="json_schema", json_schema=(name=name, schema=schema(t), strict=true))
end

function get_choices(T, response)
    T[JSON3.read(r.message.content, T) for r in response.response.choices]
end
