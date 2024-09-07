module Structured

using JSON3

include("schema.jl")  # generate a JSON schema from a Julia type
include("to_type.jl") # convert a Dicts (from JSON) into Julia types
include("openAI.jl")  # API call to OpenAI returning structured output

end # module