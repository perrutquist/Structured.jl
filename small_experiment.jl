using Structured: system, user, assistant, response_format, get_choices, OneOf
using OpenAI

"A capital city"
struct CC
    "the city"
    a::String
    "the country"
    b::String
end

choices = OpenAI.create_chat(
    ENV["OPENAI_API_KEY"],
    "gpt-4o-2024-08-06",
    [ system => "Let's roll.",
      user => "Give me some JSON!" ],
    response_format = response_format(CC),
    n = 3
) |> get_choices(CC)

dump(choices)
