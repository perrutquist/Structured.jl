module Structured

using JSON3, StructTypes

include("enum_replacement.jl") # `Option` as a replacement for `Enum`
include("schema.jl")  # generate a JSON schema from a Julia type
include("openAI.jl")  # code related to the OpenAI API

end # module