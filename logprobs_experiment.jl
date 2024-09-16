using StructuredOutputs: system, user, assistant, response_format, get_choices, OneOf
using OpenAI

struct CoinFlip
    result::OneOf{(:heads, :tails)}
end

response = OpenAI.create_chat(
    ENV["OPENAI_API_KEY"],
    "gpt-4o-2024-08-06",
    [ system => "You are a coin-flipping assistant.",
      user => "Please flip a coin for me. Respond in JSON format." ],
    response_format = response_format(CoinFlip),
    logprobs = true,
    top_logprobs = 8, # Max 20
    n = 2
)

choices = get_choices(CoinFlip, response)

dump(choices)
