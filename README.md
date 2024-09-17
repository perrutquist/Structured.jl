# StructuredOutputs.jl

StructuredOutputs.jl is a Julia package to create JSON schemas from Julia types for the [Structured Outputs](https://platform.openai.com/docs/guides/structured-outputs/structured-outputs) feature of the OpenAI API.

It also contains a few convenience functions to enable the use of these schemas together with the [OpenAI.jl](https://github.com/JuliaML/OpenAI.jl) package,
making it possible to extract replies from the Large Language Model in the form of a specific Julia type, rather than text or JSON.

The Large Language Model (LLM) will see the names of the user created `struct` types that are used, as well as their field names, and docstrings.

Individual fields can have docstrings, if the type itself has one. (As in the example below.)

It is usually best to create entirely new types for use with structured outputs, rather than re-using existing types that may have names, 
field names, and docstrings that might be less helpful to the LLM.

## Alternative

The ["data extraction" feature of PromptingTools.jl](https://github.com/svilupp/PromptingTools.jl?tab=readme-ov-file#data-extraction) does basically the same thing as this package does.

## Supported Types

The top-level object in the API call must be a struct (or NamedTuple), where the field types can be any of the following:

- User created `struct` types with supported types in all fields and default constructors
- `String`, `Symbol`, `Enum`
- `Bool`
- `Int`, and other subtypes of `Integer`
- `Float64` and other subtypes of `Real`
- `Nothing` and `Missing` (map to `null` in JSON)
- `NamedTuple` containing supported types
- `Vector{T}` of supported type `T`.
- `Union` of supported types.

## Unsupported Types

- Abstract types are not supported. Use `Union` instead.
- `Val`, and other singleton types are not supported. Use single-value `Enum` instead.
- `Dict` is not supported. Although `Dict{String, T}` yields a valid schema as a JSON `object` when `T` is a supported type, the OpenAI API wants all field names to be specified. A `Vector{@NamedTuple{key::String, value::T}}` can be used instead.
- `Tuple` also yields a valid schema, but is not supported. Use `Vector` or `NamedTuple` instead.
- `Any` yields an empty schema, which is valid but not supported by the OpenAI API.

## Example

In the below example, the prompt gives no hint as to what is expected, yet the returned data fits the documented type.

(Note: It is not possible to run this example without an API key from OpenAI.)

```julia
using StructuredOutputs: system, user, assistant, response_format, get_choices
using OpenAI

"A capital city"
struct CC
    "the city"
    a::String
    "the region or province"
    b::Union{String, Nothing}
    "the country"
    c::String
end

choices = OpenAI.create_chat(
    ENV["OPENAI_API_KEY"],
    "gpt-4o-2024-08-06",
    [ system => "Let's roll.",
      user => "Give me some JSON!" ],
    response_format = response_format(CC),
    n = 3
) |> get_choices(CC) # Returns a Vector{CC}

dump(choices)
```

Example response:
```
Array{CC}((3,))
  1: CC
    a: String "Kathmandu"
    b: String "Bagmati"
    c: String "Nepal"
  2: CC
    a: String "Tokyo"
    b: Nothing nothing
    c: String "Japan"
  3: CC
    a: String "Ottawa"
    b: String "Ontario"
    c: String "Canada"
```

## Another example

This is a Julia version of the "Chain of thought" example at https://platform.openai.com/docs/guides/structured-outputs/examples

```julia
using StructuredOutputs: system, user, assistant, response_format, get_choices
using OpenAI

struct Step
    explanation::String
    output::String
end

struct MathReasoning
    steps::Vector{Step}
    final_answer::String
end

choices = OpenAI.create_chat(
    ENV["OPENAI_API_KEY"],
    "gpt-4o-2024-08-06",
    [ system => "You are a helpful math tutor. Guide the user through the solution step by step.",
      user => "how can I solve 8x + 7 = -23" ],
    response_format = response_format(MathReasoning),
    n = 1
) |> get_choices(MathReasoning) # Returns a Vector{MathReasoning} of length n

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

## Debugging the schema

The `schema` function generates a schema from a type, for example:

```julia
using StructuredOutputs: schema
using JSON3

schema(MathReasoning) |> JSON3.pretty
```

```json
{
    "type": "object",
    "properties": {
        "steps": {
            "type": "array",
            "items": {
                "$ref": "#/$defs/Step"
            }
        },
        "final_answer": {
            "type": "string"
        }
    },
    "additionalProperties": false,
    "required": [
        "steps",
        "final_answer"
    ],
    "$defs": {
        "Step": {
            "type": "object",
            "properties": {
                "explanation": {
                    "type": "string"
                },
                "output": {
                    "type": "string"
                }
            },
            "additionalProperties": false,
            "required": [
                "explanation",
                "output"
            ]
        }
    }
}
```
