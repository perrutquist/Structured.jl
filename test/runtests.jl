using StructuredOutputs
using StructuredOutputs: system, assistant, user, get_choice, response_format
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
    @test_throws ArgumentError JSON3.read(JSON3.write(o15b), typeof(o15b))

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
        pjo = JSON3.read(jo) # Object in JSON3.Object form
        @test validate(S, pjo) === nothing
        @test validate(noS, pjo) !== nothing
        #r = StructTypes.constructfrom(t, pjo) # Object restored into type t.
        r = JSON3.read(jo, t) # skip StructTypes
        @test typeof(r) == t
        @test r == o
    end

    @test_throws ArgumentError StructuredOutputs.schema(Ptr{Int})
    @test_throws ArgumentError StructuredOutputs.schema(typeof(:a => 1))

    @test JSON3.write(StructuredOutputs.response_format(typeof((a=1,)), "response")) == "{\"type\":\"json_schema\",\"json_schema\":{\"name\":\"response\",\"schema\":{\"type\":\"object\",\"properties\":{\"a\":{\"type\":\"integer\"}},\"additionalProperties\":false,\"required\":[\"a\"]},\"strict\":true}}"

    # Documentation tests don't work for some reason?
    #@test StructuredOutputs._getdoc(Foo) == "A test object"
    #@test StructuredOutputs._getdoc(Foo, :checksum) == "Must be the number thirty-one"

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

            #if T == t1
            #    # Test that the LLM was paying attention to the documentation.
            #    @test choice.x == 31
            #end

            dump(choice)
        end
    end
end
