# Structured.jl

Structured.jl is a Julia package to create JSON schemas from Julia types for the [Structured outputs](https://platform.openai.com/docs/guides/structured-outputs/structured-outputs) feature of the OpenAI API.

It also contains a few convenience functions to enable the use of these schemas together with the [OpenAI.jl](https://github.com/JuliaML/OpenAI.jl) package,
making it possible to extract replies from the Large Language Model in the form of a specific Julia type, rather free text or JSON.

The prompt should instruct the AI to reply with JSON representing the required object, and explain what
the fields should represent. It is recommended that the type name and field names are carefully chosen, 
as they will influence the AI.

## Supported Types

- User created `struct` types with supported types in all fields and default constructors
- `String`, `Symbol`, `Enum`
- `Bool`
- `Int`, and other subtypes of `Integer`
- `Float64` and other subtypes of `Real`
- `Nothing` (maps to `null` in JSON)
- `NamedTuple`
- `Dict{S, T}` where `S<:Union{String, Symbol}` and `T` is a supported type
- `Vector{T}` of supported type `T`
- `Union` of supported types.
- `Any` (Results in an empty schema.)

## Unsupported Types

- `Tuple` is not supported. Use `Vector` or `NamedTuple` instead.
- Abstract types are not supported. Use `Union` instead.
- `Val`, `Missing`, and other singleton types. Use single-value `Enum` instead.

## Example

This example is based on the "Chain of thought" example at https://platform.openai.com/docs/guides/structured-outputs/examples

(Note: It is not possible to run this example without an API key for OpenAI.)

```julia
using Structured: system, user, assistant, response_format, get_choices
using OpenAI

struct Step
    explanation::String
    output::String
end

struct MathReasoning
    steps::Vector{Step}
    final_answer::String
end

reply = OpenAI.create_chat(
    ENV["OPENAI_API_KEY"],
    "gpt-4o-2024-08-06",
    [ system => "You are a helpful math tutor. Guide the user through the solution step by step.",
      user => "how can I solve 8x + 7 = -23" ],
    response_format = response_format(MathReasoning),
    n = 1
)

choices = get_choices(MathReasoning, reply) # Returns a Vector{MathReasoning} of length n

dump(choices[1]) # display the result
```

Example response:
```
MathReasoning
  steps: Array{Step}((6,))
    1: Step
      explanation: String "The goal is to solve for \\( x \\). We start with the equation \\( 8x + 7 = -23 \\). To isolate \\( 8x \\), we need to get rid of the \\( + 7 \\) on the left side by performing the inverse operation, which is subtraction."
      output: String "8x + 7 = -23"
    2: Step
      explanation: String "Subtract 7 from both sides of the equation to get rid of the +7 next to \\( 8x \\)."
      output: String "8x + 7 - 7 = -23 - 7"
    3: Step
      explanation: String "Simplifying both sides, we have \\( 8x = -30 \\)."
      output: String "8x = -30"
    4: Step
      explanation: String "Now, we need to isolate \\( x \\) by dividing both sides of the equation by 8."
      output: String "\\frac{8x}{8} = \\frac{-30}{8}"
    5: Step
      explanation: String "Simplifying the division, we get \\( x = -\\frac{30}{8} \\)."
      output: String "x = -\\frac{30}{8}"
    6: Step
      explanation: String "Further simplifying \\( -\\frac{30}{8} \\), we divide the numerator and the denominator by their greatest common divisor, which is 2."
      output: String "x = -\\frac{15}{4}"
  final_answer: String "x = -\\frac{15}{4}"
```
