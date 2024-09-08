module Structured

using JSON3

include("schema.jl")  # generate a JSON schema from a Julia type
include("openAI.jl")  # code related to the OpenAI API

end # module