using StructuredOutputs: system, user, assistant, response_format, get_choices, OneOf
using OpenAI

struct Spoken
    spoken::String
end

struct CodeBox
    codebox_title::Union{String, Nothing}
    clear_screen::Bool
    language::OneOf{(:Julia, :Python)}
    code::String
    output::Union{String, Nothing}
end

struct DisplayText
    display::String
    clear_screen::Bool
end

struct CodingTutorial
    video_title::String
    mp4_file_name::String
    script::Vector{Union{Spoken, CodeBox, DisplayText}}
end

choices = OpenAI.create_chat(
    ENV["OPENAI_API_KEY"],
    "gpt-4o-2024-08-06",
    [ system => "The asssistant is a skilled coder who always replies in JSON format.",
      user => 
      """
      Let's make a tutorial explaining how arrays work in Julia, for coders that are familiar with Python.
      Show equivalent code in Python and in Julia, and also the output that results from running that code.
      You may use DisplayText to display important keywords before you mention them in the spoken text.
      Set clear_screen to true when display objects are unrelated to the previous object, and false when they should 
      appear together with the previous object.
      """ ],
    response_format = response_format(CodingTutorial),
    n = 1
) |> get_choices(CodingTutorial)

println(choices[1].video_title)
println.(choices[1].script);
