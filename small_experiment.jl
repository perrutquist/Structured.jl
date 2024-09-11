using Structured: system, user, assistant, response_format, get_choice, OneOf
using OpenAI

"A capital city"
struct CC
    "the city"
    a::String
    "the country"
    b::String
end

choice = OpenAI.create_chat(
    ENV["OPENAI_API_KEY"],
    "gpt-4o-2024-08-06",
    [ system => "You're a helpful assistant.",
      user => "Give me some JSON!" ],
    response_format = response_format(CC),
    n = 1
) |> get_choice(CC)

dump(choice)
