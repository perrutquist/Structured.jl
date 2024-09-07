module Structured

using JSON3

include("schema.jl")  # generate a JSON schema from a Julia type
include("openAI.jl")  # API call to OpenAI returning structured output

end # module