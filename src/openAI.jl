@enum Role system user assistant

struct Message
    role::Role
    content::String
end

const default_model = "gpt-4o-latest"

function response_format(t)
    (type="json_schema", json_schema=schema(t))
end

function structured_completions(T, messages::Vector{Message}; model=default_model)
    # TODO
end
