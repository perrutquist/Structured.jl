module StructuredOutputs

using JSON3, StructTypes
using REPL # needed for Docs.doc in _getdoc

include("enum_replacement.jl") # `OneOf` as a replacement for `Enum`
include("logprobs.jl") # correlate logprobs of tokens with items in struct
include("schema.jl")  # generate a JSON schema from a Julia type
include("openAI.jl")  # code related to the OpenAI API
include("getdoc.jl")  # get docstrings for struct and fields

end # module