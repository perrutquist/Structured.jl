using StructuredOutputs
using StructuredOutputs: system, assistant, user, get_choice, response_format, parse_json,
        WithTopLogprobs, OneOf, get_choices, get_probability, parse_json
using Test
using JSON3
using JSONSchema
using OpenAI

abstract type FooOrBar end

# This type has documentation, for use in the API tests
"A test object"
struct Foo <: FooOrBar
    "Must be the number thirty-one"
    checksum::Int
    "A greeting"
    y::String
end

struct Bar <: FooOrBar
    foo::Foo
    next::Union{Bar, Nothing}
end

struct NoBar 
    foo::Foo
    next::Int
end

struct WhichBar
    tst::Union{Bar, NoBar}
end

struct WhichFB
    tst::FooOrBar
end

struct Baz{T}
    x::T 
    n::Int
end

@enum YN yes no

@testset "StructuredOutputs.jl" begin
    o1 = Bar(Foo(42, "Hi"), Bar(Foo(0, "bye"), nothing))
    o2 = (x="Hello", y=:World)
    o3 = (answer=yes, guide=42.0f0, b=true, f=false, next=nothing)
    o4 = (it=WhichBar(Bar(Foo(3,"hi"), nothing)))
    o5 = (it=WhichBar(NoBar(Foo(3,"hi"), 42)))
    o6 = [1+2im, 0+0im, -3-4im]
    o7 = [:Hello, :World]
    o8 = (; o1, o2, o3, o4, o5, o6, o7)
    o9 = Dict("a" => 1, "b" => 2)
    o10 = Dict{String, Any}("a" => 1, "b" => "two", "c"=>3.0)
    o11 = Any[1, "two", 3.0]
    o12 = @NamedTuple{a::Int, b::Any}((1, "two"))
    o13 = Dict("a"=>Foo(1,"a"), "b"=>Foo(2,"b"))
    o14 = Dict(:a=>Foo(1,"a"), :b=>Foo(2,"b"))
    o15a = Union{Foo,Bar}[Foo(42, "Hi"), Bar(Foo(0, "bye"), nothing)]
    o16 = Char['h', 'e', 'l', 'l', 'o']
    o17 = Baz("hi", 2)
    o18 = Baz(Foo(1,"hi"), 2)
    o19 = [StructuredOutputs.OneOf{(:yes, :no)}(:yes),]

    # For now it is better to use Union than absstract type...
    o15b = FooOrBar[Foo(42, "Hi"), Bar(Foo(0, "bye"), nothing)]
    @test_throws ArgumentError parse_json(JSON3.write(o15b), typeof(o15b))

    noS = Schema(JSON3.write(StructuredOutputs.schema(typeof((invalid=true,)))))

    for o in (o1, o2, o3, o4, o5, o6, o7, o8, o9, o10, o11, o12, o13, o14, o15a, o16, o17, o18, o19)
        t = typeof(o)
        s = StructuredOutputs.schema(t)
        js = JSON3.write(s) # schema as a JSON string
        jo = JSON3.write(o) # object as a JSON string
        #println("Schema:")
        #println(js)
        #println("Object:")
        #println(jo)
        S = Schema(js)
        pjo = parse_json(jo) # Object in JSON3.Object form
        @test validate(S, pjo) === nothing
        @test validate(noS, pjo) !== nothing
        #r = StructTypes.constructfrom(t, pjo) # Object restored into type t.
        r = parse_json(jo, t) # skip StructTypes
        @test typeof(r) == t
        @test r == o
    end

    @test_throws ArgumentError StructuredOutputs.schema(Ptr{Int})
    @test_throws ArgumentError StructuredOutputs.schema(typeof(:a => 1))

    @test JSON3.write(StructuredOutputs.response_format(typeof((a=1,)), "response")) == "{\"type\":\"json_schema\",\"json_schema\":{\"name\":\"response\",\"schema\":{\"type\":\"object\",\"properties\":{\"a\":{\"type\":\"integer\"}},\"additionalProperties\":false,\"required\":[\"a\"]},\"strict\":true}}"

    # Documentation tests don't work for some reason?
    @test StructuredOutputs._getdoc(Foo) == "A test object"
    @test StructuredOutputs._getdoc(Foo, :checksum) == "Must be the number thirty-one"

    # The below tests require an API key and consume credits. To run them:
    # using Pkg; Pkg.test("StructuredOutputs"; test_args=["--call_api"])
    if "--call_api" in ARGS
        println("Testing calls to the OpenAI API")

        t1 = Foo
        t2 = Baz{Vector{Foo}}
        t3 = @NamedTuple{number::Int, french_word::String}

        for T in (t1, t2, t3)
            JSON3.pretty(response_format(T))

            choice = OpenAI.create_chat(
                ENV["OPENAI_API_KEY"],
                "gpt-4o-mini",
                [ system => "You're a helpful assistant.",
                user => "Please give me a small JSON snippet that matches the provided schema." ],
                response_format = response_format(T),
                n = 1
            ) |> get_choice(T)

            @test choice isa T

            if T == t1
                # Test that the LLM was paying attention to the documentation.
                @test choice.checksum == 31
            end

            dump(choice)
        end
    end
end

@testset "logprobs" begin
    struct CoinFlip
        result::WithTopLogprobs{OneOf{(:heads, :tails)}}
    end
    
    response = if "--call_api" in ARGS
        println("Calling OpenAI.")
        OpenAI.create_chat(
            ENV["OPENAI_API_KEY"],
            "gpt-4o-2024-08-06",
            [ system => "You are a coin-flipping assistant.",
            user => "Please flip a coin for me. Respond in JSON format." ],
            response_format = response_format(CoinFlip),
            logprobs = true,
            top_logprobs = 8, # Max 20
            n = 1
        )
    else
        parse_json("{\"status\":200,\"response\":{\"id\":\"chatcmpl-A7z0hqnVKEzp8ULNoMNBQRR7X1w62\",\"object\":\"chat.completion\",\"created\":1726466183,\"model\":\"gpt-4o-2024-08-06\",\"choices\":[{\"index\":0,\"message\":{\"role\":\"assistant\",\"content\":\"{\\\"result\\\":\\\"tails\\\"}\",\"refusal\":null},\"logprobs\":{\"content\":[{\"token\":\"{\\\"\",\"logprob\":-1.9361265e-7,\"bytes\":[123,34],\"top_logprobs\":[{\"token\":\"{\\\"\",\"logprob\":-1.9361265e-7,\"bytes\":[123,34]},{\"token\":\"{\",\"logprob\":-15.75,\"bytes\":[123]},{\"token\":\"{\\n\",\"logprob\":-17.5,\"bytes\":[123,10]},{\"token\":\" {\\\"\",\"logprob\":-19,\"bytes\":[32,123,34]},{\"token\":\"\\n\",\"logprob\":-19.5,\"bytes\":[10]},{\"token\":\"\\n\\n\",\"logprob\":-23.625,\"bytes\":[10,10]},{\"token\":\" \",\"logprob\":-24.125,\"bytes\":[32]}]},{\"token\":\"result\",\"logprob\":0,\"bytes\":[114,101,115,117,108,116],\"top_logprobs\":[{\"token\":\"result\",\"logprob\":0,\"bytes\":[114,101,115,117,108,116]},{\"token\":\"re\",\"logprob\":-18.625,\"bytes\":[114,101]},{\"token\":\"r\",\"logprob\":-18.75,\"bytes\":[114]},{\"token\":\"res\",\"logprob\":-20,\"bytes\":[114,101,115]},{\"token\":\"!\",\"logprob\":-100,\"bytes\":[33]},{\"token\":\"\\\"\",\"logprob\":-100,\"bytes\":[34]},{\"token\":\"#\",\"logprob\":-100,\"bytes\":[35]},{\"token\":\"\$\",\"logprob\":-100,\"bytes\":[36]}]},{\"token\":\"\\\":\\\"\",\"logprob\":-5.5122365e-7,\"bytes\":[34,58,34],\"top_logprobs\":[{\"token\":\"\\\":\\\"\",\"logprob\":-5.5122365e-7,\"bytes\":[34,58,34]},{\"token\":\"\\\":\",\"logprob\":-14.625001,\"bytes\":[34,58]},{\"token\":\"\\\"\",\"logprob\":-20.25,\"bytes\":[34]},{\"token\":\"\\\":\\n\",\"logprob\":-24.9375,\"bytes\":[34,58,10]},{\"token\":\"\\\":\\n\\n\",\"logprob\":-26.0625,\"bytes\":[34,58,10,10]},{\"token\":\"\\\":\\r\\n\",\"logprob\":-28.1875,\"bytes\":[34,58,13,10]},{\"token\":\"\\\"\\n\",\"logprob\":-28.8125,\"bytes\":[34,10]},{\"token\":\"\\\"\\n\\n\",\"logprob\":-30.375,\"bytes\":[34,10,10]}]},{\"token\":\"tails\",\"logprob\":-0.5231803,\"bytes\":[116,97,105,108,115],\"top_logprobs\":[{\"token\":\"tails\",\"logprob\":-0.5231803,\"bytes\":[116,97,105,108,115]},{\"token\":\"heads\",\"logprob\":-0.8981803,\"bytes\":[104,101,97,100,115]},{\"token\":\"tail\",\"logprob\":-10.52318,\"bytes\":[116,97,105,108]},{\"token\":\"head\",\"logprob\":-10.64818,\"bytes\":[104,101,97,100]},{\"token\":\"t\",\"logprob\":-12.64818,\"bytes\":[116]},{\"token\":\"ta\",\"logprob\":-13.39818,\"bytes\":[116,97]},{\"token\":\"he\",\"logprob\":-13.96068,\"bytes\":[104,101]},{\"token\":\"h\",\"logprob\":-14.39818,\"bytes\":[104]}]},{\"token\":\"\\\"}\",\"logprob\":0,\"bytes\":[34,125],\"top_logprobs\":[{\"token\":\"\\\"}\",\"logprob\":0,\"bytes\":[34,125]},{\"token\":\"\\\"}\\n\\n\",\"logprob\":-16.875,\"bytes\":[34,125,10,10]},{\"token\":\"\\\"}\\n\",\"logprob\":-17.875,\"bytes\":[34,125,10]},{\"token\":\"\\\"\",\"logprob\":-19.25,\"bytes\":[34]},{\"token\":\"\\\"\\n\",\"logprob\":-34.25,\"bytes\":[34,10]},{\"token\":\"\\\"\\n\\n\",\"logprob\":-34.9375,\"bytes\":[34,10,10]},{\"token\":\"\\\"\\n\\n\\n\",\"logprob\":-35.875,\"bytes\":[34,10,10,10]},{\"token\":\"\\\"\\r\\n\",\"logprob\":-40.28125,\"bytes\":[34,13,10]}]}],\"refusal\":null},\"finish_reason\":\"stop\"},{\"index\":1,\"message\":{\"role\":\"assistant\",\"content\":\"{\\\"result\\\":\\\"heads\\\"}\",\"refusal\":null},\"logprobs\":{\"content\":[{\"token\":\"{\\\"\",\"logprob\":-1.9361265e-7,\"bytes\":[123,34],\"top_logprobs\":[{\"token\":\"{\\\"\",\"logprob\":-1.9361265e-7,\"bytes\":[123,34]},{\"token\":\"{\",\"logprob\":-15.75,\"bytes\":[123]},{\"token\":\"{\\n\",\"logprob\":-17.5,\"bytes\":[123,10]},{\"token\":\" {\\\"\",\"logprob\":-19,\"bytes\":[32,123,34]},{\"token\":\"\\n\",\"logprob\":-19.5,\"bytes\":[10]},{\"token\":\"\\n\\n\",\"logprob\":-23.625,\"bytes\":[10,10]},{\"token\":\" \",\"logprob\":-24.125,\"bytes\":[32]}]},{\"token\":\"result\",\"logprob\":0,\"bytes\":[114,101,115,117,108,116],\"top_logprobs\":[{\"token\":\"result\",\"logprob\":0,\"bytes\":[114,101,115,117,108,116]},{\"token\":\"re\",\"logprob\":-18.625,\"bytes\":[114,101]},{\"token\":\"r\",\"logprob\":-18.75,\"bytes\":[114]},{\"token\":\"res\",\"logprob\":-20,\"bytes\":[114,101,115]},{\"token\":\"!\",\"logprob\":-100,\"bytes\":[33]},{\"token\":\"\\\"\",\"logprob\":-100,\"bytes\":[34]},{\"token\":\"#\",\"logprob\":-100,\"bytes\":[35]},{\"token\":\"\$\",\"logprob\":-100,\"bytes\":[36]}]},{\"token\":\"\\\":\\\"\",\"logprob\":-5.5122365e-7,\"bytes\":[34,58,34],\"top_logprobs\":[{\"token\":\"\\\":\\\"\",\"logprob\":-5.5122365e-7,\"bytes\":[34,58,34]},{\"token\":\"\\\":\",\"logprob\":-14.625001,\"bytes\":[34,58]},{\"token\":\"\\\"\",\"logprob\":-20.25,\"bytes\":[34]},{\"token\":\"\\\":\\n\",\"logprob\":-24.9375,\"bytes\":[34,58,10]},{\"token\":\"\\\":\\n\\n\",\"logprob\":-26.0625,\"bytes\":[34,58,10,10]},{\"token\":\"\\\":\\r\\n\",\"logprob\":-28.1875,\"bytes\":[34,58,13,10]},{\"token\":\"\\\"\\n\",\"logprob\":-28.8125,\"bytes\":[34,10]},{\"token\":\"\\\"\\n\\n\",\"logprob\":-30.375,\"bytes\":[34,10,10]}]},{\"token\":\"heads\",\"logprob\":-0.8981803,\"bytes\":[104,101,97,100,115],\"top_logprobs\":[{\"token\":\"tails\",\"logprob\":-0.5231803,\"bytes\":[116,97,105,108,115]},{\"token\":\"heads\",\"logprob\":-0.8981803,\"bytes\":[104,101,97,100,115]},{\"token\":\"tail\",\"logprob\":-10.52318,\"bytes\":[116,97,105,108]},{\"token\":\"head\",\"logprob\":-10.64818,\"bytes\":[104,101,97,100]},{\"token\":\"t\",\"logprob\":-12.64818,\"bytes\":[116]},{\"token\":\"ta\",\"logprob\":-13.39818,\"bytes\":[116,97]},{\"token\":\"he\",\"logprob\":-13.96068,\"bytes\":[104,101]},{\"token\":\"h\",\"logprob\":-14.39818,\"bytes\":[104]}]},{\"token\":\"\\\"}\",\"logprob\":0,\"bytes\":[34,125],\"top_logprobs\":[{\"token\":\"\\\"}\",\"logprob\":0,\"bytes\":[34,125]},{\"token\":\"\\\"}\\n\\n\",\"logprob\":-16.875,\"bytes\":[34,125,10,10]},{\"token\":\"\\\"}\\n\",\"logprob\":-17.5,\"bytes\":[34,125,10]},{\"token\":\"\\\"\",\"logprob\":-19.25,\"bytes\":[34]},{\"token\":\"\\\"\\n\",\"logprob\":-34.0625,\"bytes\":[34,10]},{\"token\":\"\\\"\\n\\n\",\"logprob\":-35,\"bytes\":[34,10,10]},{\"token\":\"\\\"\\n\\n\\n\",\"logprob\":-35.875,\"bytes\":[34,10,10,10]},{\"token\":\"\\\"\\r\\n\",\"logprob\":-40.1875,\"bytes\":[34,13,10]}]}],\"refusal\":null},\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":64,\"completion_tokens\":10,\"total_tokens\":74,\"completion_tokens_details\":{\"reasoning_tokens\":0}},\"system_fingerprint\":\"fp_143bb8492c\"}}")
    end

    chs = get_choices(CoinFlip, response)

    @test chs isa Vector{CoinFlip}
    @test 0.3 < get_probability(chs[1].result, :heads) < 0.7
    @test 0.99 < sum(get_probability(chs[1].result)) ≤ 1.0   

    "The result of a coin flip"
    struct CoinFlipBool
        "true for heads, false for tails"
        result::WithTopLogprobs{Bool}
    end

    response = if "--call_api" in ARGS
        println("Calling OpenAI.")
        OpenAI.create_chat(
            ENV["OPENAI_API_KEY"],
            "gpt-4o-2024-08-06",
            [ system => "You are a coin-flipping assistant.",
            user => "Please flip a coin for me. Respond in JSON format." ],
            response_format = response_format(CoinFlipBool),
            logprobs = true,
            top_logprobs = 8, # Max 20
            n = 1
        )
    else
        parse_json("{\"status\":200,\"response\":{\"id\":\"chatcmpl-AAbrJwGjTA2bON6ikcH91jMg49LSu\",\"object\":\"chat.completion\",\"created\":1727092173,\"model\":\"gpt-4o-2024-08-06\",\"choices\":[{\"index\":0,\"message\":{\"role\":\"assistant\",\"content\":\"{\\\"result\\\":true}\",\"refusal\":null},\"logprobs\":{\"content\":[{\"token\":\"{\\\"\",\"logprob\":-9.0883464e-7,\"bytes\":[123,34],\"top_logprobs\":[{\"token\":\"{\\\"\",\"logprob\":-9.0883464e-7,\"bytes\":[123,34]},{\"token\":\"{\",\"logprob\":-14.250001,\"bytes\":[123]},{\"token\":\"{\\n\",\"logprob\":-16.25,\"bytes\":[123,10]},{\"token\":\" {\\\"\",\"logprob\":-19.25,\"bytes\":[32,123,34]},{\"token\":\"\\n\",\"logprob\":-21.125,\"bytes\":[10]},{\"token\":\"{\\r\\n\",\"logprob\":-22.5,\"bytes\":[123,13,10]},{\"token\":\"{\\n\\n\",\"logprob\":-22.625,\"bytes\":[123,10,10]}]},{\"token\":\"result\",\"logprob\":0,\"bytes\":[114,101,115,117,108,116],\"top_logprobs\":[{\"token\":\"result\",\"logprob\":0,\"bytes\":[114,101,115,117,108,116]},{\"token\":\"re\",\"logprob\":-17.75,\"bytes\":[114,101]},{\"token\":\"res\",\"logprob\":-18.875,\"bytes\":[114,101,115]},{\"token\":\"r\",\"logprob\":-19.0625,\"bytes\":[114]},{\"token\":\"!\",\"logprob\":-100,\"bytes\":[33]},{\"token\":\"\\\"\",\"logprob\":-100,\"bytes\":[34]},{\"token\":\"#\",\"logprob\":-100,\"bytes\":[35]},{\"token\":\"\$\",\"logprob\":-100,\"bytes\":[36]}]},{\"token\":\"\\\":\",\"logprob\":0,\"bytes\":[34,58],\"top_logprobs\":[{\"token\":\"\\\":\",\"logprob\":0,\"bytes\":[34,58]},{\"token\":\"\\\"\",\"logprob\":-18.6875,\"bytes\":[34]},{\"token\":\"\\\":\\n\",\"logprob\":-20.5625,\"bytes\":[34,58,10]},{\"token\":\"\\\":\\n\\n\",\"logprob\":-21.3125,\"bytes\":[34,58,10,10]},{\"token\":\"\\\":\\r\\n\",\"logprob\":-21.875,\"bytes\":[34,58,13,10]},{\"token\":\"\\\"\\n\",\"logprob\":-24.5,\"bytes\":[34,10]},{\"token\":\"\\\"\\n\\n\",\"logprob\":-25.125,\"bytes\":[34,10,10]},{\"token\":\"\\\"\\r\\n\",\"logprob\":-28.65625,\"bytes\":[34,13,10]}]},{\"token\":\"true\",\"logprob\":-0.20157677,\"bytes\":[116,114,117,101],\"top_logprobs\":[{\"token\":\"true\",\"logprob\":-0.20157677,\"bytes\":[116,114,117,101]},{\"token\":\"false\",\"logprob\":-1.7015767,\"bytes\":[102,97,108,115,101]},{\"token\":\" true\",\"logprob\":-8.951577,\"bytes\":[32,116,114,117,101]},{\"token\":\" false\",\"logprob\":-10.326577,\"bytes\":[32,102,97,108,115,101]},{\"token\":\"tru\",\"logprob\":-14.639077,\"bytes\":[116,114,117]},{\"token\":\"\\ttrue\",\"logprob\":-15.139077,\"bytes\":[9,116,114,117,101]},{\"token\":\"tr\",\"logprob\":-15.764077,\"bytes\":[116,114]},{\"token\":\"\\tfalse\",\"logprob\":-16.014076,\"bytes\":[9,102,97,108,115,101]}]},{\"token\":\"}\",\"logprob\":-1.9361265e-7,\"bytes\":[125],\"top_logprobs\":[{\"token\":\"}\",\"logprob\":-1.9361265e-7,\"bytes\":[125]},{\"token\":\"}\\n\",\"logprob\":-15.75,\"bytes\":[125,10]},{\"token\":\"}\\n\\n\",\"logprob\":-17.75,\"bytes\":[125,10,10]},{\"token\":\" }\",\"logprob\":-19.125,\"bytes\":[32,125]},{\"token\":\"}\\n\\n\\n\",\"logprob\":-20.125,\"bytes\":[125,10,10,10]},{\"token\":\"}\\r\\n\",\"logprob\":-24.875,\"bytes\":[125,13,10]},{\"token\":\"}\\n\\n\\n\\n\",\"logprob\":-25.5,\"bytes\":[125,10,10,10,10]},{\"token\":\"}\\n\\n\\n\\n\\n\\n\",\"logprob\":-26.625,\"bytes\":[125,10,10,10,10,10,10]}]}],\"refusal\":null},\"finish_reason\":\"stop\"},{\"index\":1,\"message\":{\"role\":\"assistant\",\"content\":\"{\\\"result\\\":true}\",\"refusal\":null},\"logprobs\":{\"content\":[{\"token\":\"{\\\"\",\"logprob\":-9.0883464e-7,\"bytes\":[123,34],\"top_logprobs\":[{\"token\":\"{\\\"\",\"logprob\":-9.0883464e-7,\"bytes\":[123,34]},{\"token\":\"{\",\"logprob\":-14.250001,\"bytes\":[123]},{\"token\":\"{\\n\",\"logprob\":-16.25,\"bytes\":[123,10]},{\"token\":\" {\\\"\",\"logprob\":-19.25,\"bytes\":[32,123,34]},{\"token\":\"\\n\",\"logprob\":-21.125,\"bytes\":[10]},{\"token\":\"{\\r\\n\",\"logprob\":-22.5,\"bytes\":[123,13,10]},{\"token\":\"{\\n\\n\",\"logprob\":-22.625,\"bytes\":[123,10,10]}]},{\"token\":\"result\",\"logprob\":0,\"bytes\":[114,101,115,117,108,116],\"top_logprobs\":[{\"token\":\"result\",\"logprob\":0,\"bytes\":[114,101,115,117,108,116]},{\"token\":\"re\",\"logprob\":-17.75,\"bytes\":[114,101]},{\"token\":\"res\",\"logprob\":-18.875,\"bytes\":[114,101,115]},{\"token\":\"r\",\"logprob\":-19.0625,\"bytes\":[114]},{\"token\":\"!\",\"logprob\":-100,\"bytes\":[33]},{\"token\":\"\\\"\",\"logprob\":-100,\"bytes\":[34]},{\"token\":\"#\",\"logprob\":-100,\"bytes\":[35]},{\"token\":\"\$\",\"logprob\":-100,\"bytes\":[36]}]},{\"token\":\"\\\":\",\"logprob\":0,\"bytes\":[34,58],\"top_logprobs\":[{\"token\":\"\\\":\",\"logprob\":0,\"bytes\":[34,58]},{\"token\":\"\\\"\",\"logprob\":-18.6875,\"bytes\":[34]},{\"token\":\"\\\":\\n\",\"logprob\":-20.5625,\"bytes\":[34,58,10]},{\"token\":\"\\\":\\n\\n\",\"logprob\":-21.3125,\"bytes\":[34,58,10,10]},{\"token\":\"\\\":\\r\\n\",\"logprob\":-21.875,\"bytes\":[34,58,13,10]},{\"token\":\"\\\"\\n\",\"logprob\":-24.5,\"bytes\":[34,10]},{\"token\":\"\\\"\\n\\n\",\"logprob\":-25.125,\"bytes\":[34,10,10]},{\"token\":\"\\\"\\r\\n\",\"logprob\":-28.65625,\"bytes\":[34,13,10]}]},{\"token\":\"true\",\"logprob\":-0.20157677,\"bytes\":[116,114,117,101],\"top_logprobs\":[{\"token\":\"true\",\"logprob\":-0.20157677,\"bytes\":[116,114,117,101]},{\"token\":\"false\",\"logprob\":-1.7015767,\"bytes\":[102,97,108,115,101]},{\"token\":\" true\",\"logprob\":-8.951577,\"bytes\":[32,116,114,117,101]},{\"token\":\" false\",\"logprob\":-10.326577,\"bytes\":[32,102,97,108,115,101]},{\"token\":\"tru\",\"logprob\":-14.639077,\"bytes\":[116,114,117]},{\"token\":\"\\ttrue\",\"logprob\":-15.139077,\"bytes\":[9,116,114,117,101]},{\"token\":\"tr\",\"logprob\":-15.764077,\"bytes\":[116,114]},{\"token\":\"\\tfalse\",\"logprob\":-16.014076,\"bytes\":[9,102,97,108,115,101]}]},{\"token\":\"}\",\"logprob\":-1.9361265e-7,\"bytes\":[125],\"top_logprobs\":[{\"token\":\"}\",\"logprob\":-1.9361265e-7,\"bytes\":[125]},{\"token\":\"}\\n\",\"logprob\":-15.75,\"bytes\":[125,10]},{\"token\":\"}\\n\\n\",\"logprob\":-17.75,\"bytes\":[125,10,10]},{\"token\":\" }\",\"logprob\":-19.125,\"bytes\":[32,125]},{\"token\":\"}\\n\\n\\n\",\"logprob\":-20.125,\"bytes\":[125,10,10,10]},{\"token\":\"}\\r\\n\",\"logprob\":-24.875,\"bytes\":[125,13,10]},{\"token\":\"}\\n\\n\\n\\n\",\"logprob\":-25.5,\"bytes\":[125,10,10,10,10]},{\"token\":\"}\\n\\n\\n\\n\\n\\n\",\"logprob\":-26.625,\"bytes\":[125,10,10,10,10,10,10]}]}],\"refusal\":null},\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":78,\"completion_tokens\":10,\"total_tokens\":88,\"completion_tokens_details\":{\"reasoning_tokens\":0}},\"system_fingerprint\":\"fp_5050236cbd\"}}")
    end

    chs = get_choices(CoinFlipBool, response)

    @test chs isa Vector{CoinFlipBool}
    @test 0.1 < get_probability(chs[1].result, true) < 0.9
    @test 0.99 < sum(last.(get_probability(chs[1].result))) ≤ 1.0   

    Flip = WithTopLogprobs{OneOf{(:heads, :tails)}}

    response = if "--call_api" in ARGS
        println("Calling OpenAI.")
        OpenAI.create_chat(
            ENV["OPENAI_API_KEY"],
            "gpt-4o-2024-08-06",
            [ system => "You are a coin-flipping assistant.",
            user => "Please flip three coins for me. Respond in JSON format." ],
            response_format = response_format(@NamedTuple{(response::Vector{Flip})}),
            logprobs = true,
            top_logprobs = 8, # Max 20
            n = 1
        )
    else
        parse_json("{\"status\":200,\"response\":{\"id\":\"chatcmpl-AAd3y0oZ1eC59c2REfiSAX9colm3v\",\"object\":\"chat.completion\",\"created\":1727096802,\"model\":\"gpt-4o-2024-08-06\",\"choices\":[{\"index\":0,\"message\":{\"role\":\"assistant\",\"content\":\"{\\\"response\\\":[\\\"tails\\\",\\\"heads\\\",\\\"tails\\\"]}\",\"refusal\":null},\"logprobs\":{\"content\":[{\"token\":\"{\\\"\",\"logprob\":-7.9418505e-6,\"bytes\":[123,34],\"top_logprobs\":[{\"token\":\"{\\\"\",\"logprob\":-7.9418505e-6,\"bytes\":[123,34]},{\"token\":\"{\",\"logprob\":-16.750008,\"bytes\":[123]},{\"token\":\"{\\n\",\"logprob\":-17.500008,\"bytes\":[123,10]},{\"token\":\" {\\\"\",\"logprob\":-19.500008,\"bytes\":[32,123,34]},{\"token\":\"\\n\",\"logprob\":-22.000008,\"bytes\":[10]},{\"token\":\"\\n\\n\",\"logprob\":-24.625008,\"bytes\":[10,10]},{\"token\":\"{\\n\\n\",\"logprob\":-25.125008,\"bytes\":[123,10,10]}]},{\"token\":\"response\",\"logprob\":0,\"bytes\":[114,101,115,112,111,110,115,101],\"top_logprobs\":[{\"token\":\"response\",\"logprob\":0,\"bytes\":[114,101,115,112,111,110,115,101]},{\"token\":\"re\",\"logprob\":-18.625,\"bytes\":[114,101]},{\"token\":\"r\",\"logprob\":-19.125,\"bytes\":[114]},{\"token\":\"respons\",\"logprob\":-19.875,\"bytes\":[114,101,115,112,111,110,115]},{\"token\":\"res\",\"logprob\":-21.125,\"bytes\":[114,101,115]},{\"token\":\"resp\",\"logprob\":-22.375,\"bytes\":[114,101,115,112]},{\"token\":\"!\",\"logprob\":-100,\"bytes\":[33]},{\"token\":\"\\\"\",\"logprob\":-100,\"bytes\":[34]}]},{\"token\":\"\\\":[\\\"\",\"logprob\":-3.1281633e-7,\"bytes\":[34,58,91,34],\"top_logprobs\":[{\"token\":\"\\\":[\\\"\",\"logprob\":-3.1281633e-7,\"bytes\":[34,58,91,34]},{\"token\":\"\\\":[\",\"logprob\":-15.625,\"bytes\":[34,58,91]},{\"token\":\"\\\":\",\"logprob\":-16.25,\"bytes\":[34,58]},{\"token\":\"\\\":[]\",\"logprob\":-18.25,\"bytes\":[34,58,91,93]},{\"token\":\"\\\"\",\"logprob\":-23.375,\"bytes\":[34]},{\"token\":\"\\\":\\n\\n\",\"logprob\":-26.625,\"bytes\":[34,58,10,10]},{\"token\":\"\\\":\\n\",\"logprob\":-27.25,\"bytes\":[34,58,10]},{\"token\":\"\\\":\\r\\n\",\"logprob\":-29.375,\"bytes\":[34,58,13,10]}]},{\"token\":\"tails\",\"logprob\":-0.6932126,\"bytes\":[116,97,105,108,115],\"top_logprobs\":[{\"token\":\"tails\",\"logprob\":-0.6932126,\"bytes\":[116,97,105,108,115]},{\"token\":\"heads\",\"logprob\":-0.6932126,\"bytes\":[104,101,97,100,115]},{\"token\":\"head\",\"logprob\":-10.1932125,\"bytes\":[104,101,97,100]},{\"token\":\"tail\",\"logprob\":-10.6932125,\"bytes\":[116,97,105,108]},{\"token\":\"t\",\"logprob\":-12.8182125,\"bytes\":[116]},{\"token\":\"ta\",\"logprob\":-13.8182125,\"bytes\":[116,97]},{\"token\":\"he\",\"logprob\":-13.9432125,\"bytes\":[104,101]},{\"token\":\"h\",\"logprob\":-14.6307125,\"bytes\":[104]}]},{\"token\":\"\\\",\\\"\",\"logprob\":-9.0883464e-7,\"bytes\":[34,44,34],\"top_logprobs\":[{\"token\":\"\\\",\\\"\",\"logprob\":-9.0883464e-7,\"bytes\":[34,44,34]},{\"token\":\"\\\"]\",\"logprob\":-14.000001,\"bytes\":[34,93]},{\"token\":\"\\\",\",\"logprob\":-18.5,\"bytes\":[34,44]},{\"token\":\"\\\"\",\"logprob\":-21.375,\"bytes\":[34]},{\"token\":\"\\\"]}\\n\",\"logprob\":-23.125,\"bytes\":[34,93,125,10]},{\"token\":\"\\\",\\n\",\"logprob\":-24.625,\"bytes\":[34,44,10]},{\"token\":\"\\\"]\\n\\n\",\"logprob\":-27,\"bytes\":[34,93,10,10]},{\"token\":\"\\\"]\\n\",\"logprob\":-27.25,\"bytes\":[34,93,10]}]},{\"token\":\"heads\",\"logprob\":-0.16033511,\"bytes\":[104,101,97,100,115],\"top_logprobs\":[{\"token\":\"heads\",\"logprob\":-0.16033511,\"bytes\":[104,101,97,100,115]},{\"token\":\"tails\",\"logprob\":-1.9103351,\"bytes\":[116,97,105,108,115]},{\"token\":\"head\",\"logprob\":-9.410336,\"bytes\":[104,101,97,100]},{\"token\":\"tail\",\"logprob\":-10.660336,\"bytes\":[116,97,105,108]},{\"token\":\"t\",\"logprob\":-13.035336,\"bytes\":[116]},{\"token\":\"he\",\"logprob\":-13.285336,\"bytes\":[104,101]},{\"token\":\"ta\",\"logprob\":-14.222836,\"bytes\":[116,97]},{\"token\":\"h\",\"logprob\":-14.347836,\"bytes\":[104]}]},{\"token\":\"\\\",\\\"\",\"logprob\":0,\"bytes\":[34,44,34],\"top_logprobs\":[{\"token\":\"\\\",\\\"\",\"logprob\":0,\"bytes\":[34,44,34]},{\"token\":\"\\\"]\",\"logprob\":-19,\"bytes\":[34,93]},{\"token\":\"\\\"\",\"logprob\":-21,\"bytes\":[34]},{\"token\":\"\\\",\",\"logprob\":-21.375,\"bytes\":[34,44]},{\"token\":\"\\\"]}\\n\",\"logprob\":-25.875,\"bytes\":[34,93,125,10]},{\"token\":\"\\\",\\n\",\"logprob\":-27,\"bytes\":[34,44,10]},{\"token\":\"\\\"]\\n\\n\",\"logprob\":-27.625,\"bytes\":[34,93,10,10]},{\"token\":\"\\\"]\\n\",\"logprob\":-29.5,\"bytes\":[34,93,10]}]},{\"token\":\"tails\",\"logprob\":-0.974131,\"bytes\":[116,97,105,108,115],\"top_logprobs\":[{\"token\":\"heads\",\"logprob\":-0.47413102,\"bytes\":[104,101,97,100,115]},{\"token\":\"tails\",\"logprob\":-0.974131,\"bytes\":[116,97,105,108,115]},{\"token\":\"head\",\"logprob\":-10.224131,\"bytes\":[104,101,97,100]},{\"token\":\"tail\",\"logprob\":-11.099131,\"bytes\":[116,97,105,108]},{\"token\":\"t\",\"logprob\":-13.724131,\"bytes\":[116]},{\"token\":\"ta\",\"logprob\":-14.224131,\"bytes\":[116,97]},{\"token\":\"he\",\"logprob\":-14.474131,\"bytes\":[104,101]},{\"token\":\"h\",\"logprob\":-15.849131,\"bytes\":[104]}]},{\"token\":\"\\\"]\",\"logprob\":-3.1281633e-7,\"bytes\":[34,93],\"top_logprobs\":[{\"token\":\"\\\"]\",\"logprob\":-3.1281633e-7,\"bytes\":[34,93]},{\"token\":\"\\\"]}\\n\",\"logprob\":-15.25,\"bytes\":[34,93,125,10]},{\"token\":\"\\\",\\\"\",\"logprob\":-20.375,\"bytes\":[34,44,34]},{\"token\":\"\\\"\",\"logprob\":-20.625,\"bytes\":[34]},{\"token\":\"\\\",\",\"logprob\":-23.875,\"bytes\":[34,44]},{\"token\":\"\\\"]\\n\\n\",\"logprob\":-27.125,\"bytes\":[34,93,10,10]},{\"token\":\"\\\"]\\n\",\"logprob\":-27.1875,\"bytes\":[34,93,10]},{\"token\":\"\\\"]\\r\\n\",\"logprob\":-29.5,\"bytes\":[34,93,13,10]}]},{\"token\":\"}\",\"logprob\":-1.9361265e-7,\"bytes\":[125],\"top_logprobs\":[{\"token\":\"}\",\"logprob\":-1.9361265e-7,\"bytes\":[125]},{\"token\":\"}\\n\\n\",\"logprob\":-15.625,\"bytes\":[125,10,10]},{\"token\":\"}\\n\\n\\n\",\"logprob\":-18.375,\"bytes\":[125,10,10,10]},{\"token\":\" }\",\"logprob\":-20.625,\"bytes\":[32,125]},{\"token\":\"}\\r\\n\",\"logprob\":-22.375,\"bytes\":[125,13,10]},{\"token\":\"}\\n\\n\\n\\n\",\"logprob\":-22.875,\"bytes\":[125,10,10,10,10]},{\"token\":\"}\\n\",\"logprob\":-23.75,\"bytes\":[125,10]},{\"token\":\"}\\r\\n\\r\\n\",\"logprob\":-23.75,\"bytes\":[125,13,10,13,10]}]}],\"refusal\":null},\"finish_reason\":\"stop\"},{\"index\":1,\"message\":{\"role\":\"assistant\",\"content\":\"{\\\"response\\\":[\\\"tails\\\",\\\"heads\\\",\\\"tails\\\"]}\",\"refusal\":null},\"logprobs\":{\"content\":[{\"token\":\"{\\\"\",\"logprob\":-7.9418505e-6,\"bytes\":[123,34],\"top_logprobs\":[{\"token\":\"{\\\"\",\"logprob\":-7.9418505e-6,\"bytes\":[123,34]},{\"token\":\"{\",\"logprob\":-16.750008,\"bytes\":[123]},{\"token\":\"{\\n\",\"logprob\":-17.500008,\"bytes\":[123,10]},{\"token\":\" {\\\"\",\"logprob\":-19.500008,\"bytes\":[32,123,34]},{\"token\":\"\\n\",\"logprob\":-22.000008,\"bytes\":[10]},{\"token\":\"\\n\\n\",\"logprob\":-24.625008,\"bytes\":[10,10]},{\"token\":\"{\\n\\n\",\"logprob\":-25.125008,\"bytes\":[123,10,10]}]},{\"token\":\"response\",\"logprob\":0,\"bytes\":[114,101,115,112,111,110,115,101],\"top_logprobs\":[{\"token\":\"response\",\"logprob\":0,\"bytes\":[114,101,115,112,111,110,115,101]},{\"token\":\"re\",\"logprob\":-18.625,\"bytes\":[114,101]},{\"token\":\"r\",\"logprob\":-19.125,\"bytes\":[114]},{\"token\":\"respons\",\"logprob\":-19.875,\"bytes\":[114,101,115,112,111,110,115]},{\"token\":\"res\",\"logprob\":-21.125,\"bytes\":[114,101,115]},{\"token\":\"resp\",\"logprob\":-22.375,\"bytes\":[114,101,115,112]},{\"token\":\"!\",\"logprob\":-100,\"bytes\":[33]},{\"token\":\"\\\"\",\"logprob\":-100,\"bytes\":[34]}]},{\"token\":\"\\\":[\\\"\",\"logprob\":-3.1281633e-7,\"bytes\":[34,58,91,34],\"top_logprobs\":[{\"token\":\"\\\":[\\\"\",\"logprob\":-3.1281633e-7,\"bytes\":[34,58,91,34]},{\"token\":\"\\\":[\",\"logprob\":-15.625,\"bytes\":[34,58,91]},{\"token\":\"\\\":\",\"logprob\":-16.25,\"bytes\":[34,58]},{\"token\":\"\\\":[]\",\"logprob\":-18.25,\"bytes\":[34,58,91,93]},{\"token\":\"\\\"\",\"logprob\":-23.375,\"bytes\":[34]},{\"token\":\"\\\":\\n\\n\",\"logprob\":-26.625,\"bytes\":[34,58,10,10]},{\"token\":\"\\\":\\n\",\"logprob\":-27.25,\"bytes\":[34,58,10]},{\"token\":\"\\\":\\r\\n\",\"logprob\":-29.375,\"bytes\":[34,58,13,10]}]},{\"token\":\"tails\",\"logprob\":-0.6932126,\"bytes\":[116,97,105,108,115],\"top_logprobs\":[{\"token\":\"tails\",\"logprob\":-0.6932126,\"bytes\":[116,97,105,108,115]},{\"token\":\"heads\",\"logprob\":-0.6932126,\"bytes\":[104,101,97,100,115]},{\"token\":\"head\",\"logprob\":-10.1932125,\"bytes\":[104,101,97,100]},{\"token\":\"tail\",\"logprob\":-10.6932125,\"bytes\":[116,97,105,108]},{\"token\":\"t\",\"logprob\":-12.8182125,\"bytes\":[116]},{\"token\":\"ta\",\"logprob\":-13.8182125,\"bytes\":[116,97]},{\"token\":\"he\",\"logprob\":-13.9432125,\"bytes\":[104,101]},{\"token\":\"h\",\"logprob\":-14.6307125,\"bytes\":[104]}]},{\"token\":\"\\\",\\\"\",\"logprob\":-9.0883464e-7,\"bytes\":[34,44,34],\"top_logprobs\":[{\"token\":\"\\\",\\\"\",\"logprob\":-9.0883464e-7,\"bytes\":[34,44,34]},{\"token\":\"\\\"]\",\"logprob\":-14.000001,\"bytes\":[34,93]},{\"token\":\"\\\",\",\"logprob\":-18.5,\"bytes\":[34,44]},{\"token\":\"\\\"\",\"logprob\":-21.375,\"bytes\":[34]},{\"token\":\"\\\"]}\\n\",\"logprob\":-23.125,\"bytes\":[34,93,125,10]},{\"token\":\"\\\",\\n\",\"logprob\":-24.625,\"bytes\":[34,44,10]},{\"token\":\"\\\"]\\n\\n\",\"logprob\":-27,\"bytes\":[34,93,10,10]},{\"token\":\"\\\"]\\n\",\"logprob\":-27.25,\"bytes\":[34,93,10]}]},{\"token\":\"heads\",\"logprob\":-0.16033511,\"bytes\":[104,101,97,100,115],\"top_logprobs\":[{\"token\":\"heads\",\"logprob\":-0.16033511,\"bytes\":[104,101,97,100,115]},{\"token\":\"tails\",\"logprob\":-1.9103351,\"bytes\":[116,97,105,108,115]},{\"token\":\"head\",\"logprob\":-9.410336,\"bytes\":[104,101,97,100]},{\"token\":\"tail\",\"logprob\":-10.660336,\"bytes\":[116,97,105,108]},{\"token\":\"t\",\"logprob\":-13.035336,\"bytes\":[116]},{\"token\":\"he\",\"logprob\":-13.285336,\"bytes\":[104,101]},{\"token\":\"ta\",\"logprob\":-14.222836,\"bytes\":[116,97]},{\"token\":\"h\",\"logprob\":-14.347836,\"bytes\":[104]}]},{\"token\":\"\\\",\\\"\",\"logprob\":0,\"bytes\":[34,44,34],\"top_logprobs\":[{\"token\":\"\\\",\\\"\",\"logprob\":0,\"bytes\":[34,44,34]},{\"token\":\"\\\"]\",\"logprob\":-19,\"bytes\":[34,93]},{\"token\":\"\\\"\",\"logprob\":-21,\"bytes\":[34]},{\"token\":\"\\\",\",\"logprob\":-21.375,\"bytes\":[34,44]},{\"token\":\"\\\"]}\\n\",\"logprob\":-25.875,\"bytes\":[34,93,125,10]},{\"token\":\"\\\",\\n\",\"logprob\":-27,\"bytes\":[34,44,10]},{\"token\":\"\\\"]\\n\\n\",\"logprob\":-27.625,\"bytes\":[34,93,10,10]},{\"token\":\"\\\"]\\n\",\"logprob\":-29.5,\"bytes\":[34,93,10]}]},{\"token\":\"tails\",\"logprob\":-0.974131,\"bytes\":[116,97,105,108,115],\"top_logprobs\":[{\"token\":\"heads\",\"logprob\":-0.47413102,\"bytes\":[104,101,97,100,115]},{\"token\":\"tails\",\"logprob\":-0.974131,\"bytes\":[116,97,105,108,115]},{\"token\":\"head\",\"logprob\":-10.224131,\"bytes\":[104,101,97,100]},{\"token\":\"tail\",\"logprob\":-11.099131,\"bytes\":[116,97,105,108]},{\"token\":\"t\",\"logprob\":-13.724131,\"bytes\":[116]},{\"token\":\"ta\",\"logprob\":-14.224131,\"bytes\":[116,97]},{\"token\":\"he\",\"logprob\":-14.474131,\"bytes\":[104,101]},{\"token\":\"h\",\"logprob\":-15.849131,\"bytes\":[104]}]},{\"token\":\"\\\"]\",\"logprob\":-3.1281633e-7,\"bytes\":[34,93],\"top_logprobs\":[{\"token\":\"\\\"]\",\"logprob\":-3.1281633e-7,\"bytes\":[34,93]},{\"token\":\"\\\"]}\\n\",\"logprob\":-15.25,\"bytes\":[34,93,125,10]},{\"token\":\"\\\",\\\"\",\"logprob\":-20.375,\"bytes\":[34,44,34]},{\"token\":\"\\\"\",\"logprob\":-20.625,\"bytes\":[34]},{\"token\":\"\\\",\",\"logprob\":-23.875,\"bytes\":[34,44]},{\"token\":\"\\\"]\\n\\n\",\"logprob\":-27.125,\"bytes\":[34,93,10,10]},{\"token\":\"\\\"]\\n\",\"logprob\":-27.1875,\"bytes\":[34,93,10]},{\"token\":\"\\\"]\\r\\n\",\"logprob\":-29.5,\"bytes\":[34,93,13,10]}]},{\"token\":\"}\",\"logprob\":-1.9361265e-7,\"bytes\":[125],\"top_logprobs\":[{\"token\":\"}\",\"logprob\":-1.9361265e-7,\"bytes\":[125]},{\"token\":\"}\\n\\n\",\"logprob\":-15.625,\"bytes\":[125,10,10]},{\"token\":\"}\\n\\n\\n\",\"logprob\":-18.375,\"bytes\":[125,10,10,10]},{\"token\":\" }\",\"logprob\":-20.625,\"bytes\":[32,125]},{\"token\":\"}\\r\\n\",\"logprob\":-22.375,\"bytes\":[125,13,10]},{\"token\":\"}\\n\\n\\n\\n\",\"logprob\":-22.875,\"bytes\":[125,10,10,10,10]},{\"token\":\"}\\n\",\"logprob\":-23.75,\"bytes\":[125,10]},{\"token\":\"}\\r\\n\\r\\n\",\"logprob\":-23.75,\"bytes\":[125,13,10,13,10]}]}],\"refusal\":null},\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":70,\"completion_tokens\":20,\"total_tokens\":90,\"completion_tokens_details\":{\"reasoning_tokens\":0}},\"system_fingerprint\":\"fp_5050236cbd\"}}")
    end

    chs = get_choices(@NamedTuple{(response::Vector{Flip})}, response)

    @test 0.4 < get_probability(chs[1].response[1], :heads) < 0.6
    @test 0.99 < sum(get_probability(chs[1].response[1])) ≤ 1.0   
end