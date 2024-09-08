using Structured
using Test
using JSON3
using JSONSchema

abstract type FooOrBar end

struct Foo <: FooOrBar
    x::Int
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

@testset "Structured.jl" begin
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

    # For now it is better to use Union than absstract type...
    o15b = FooOrBar[Foo(42, "Hi"), Bar(Foo(0, "bye"), nothing)]
    @test_throws ArgumentError JSON3.read(JSON3.write(o15b), typeof(o15b))

    noS = Schema(JSON3.write(Structured.schema(typeof((invalid=true,)))))

    for o in (o1, o2, o3, o4, o5, o6, o7, o8, o9, o10, o11, o12, o13, o14, o15a, o16, o17, o18)
        t = typeof(o)
        s = Structured.schema(t)
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

    @test_throws ArgumentError Structured.schema(Ptr{Int})
    @test_throws ArgumentError Structured.schema(typeof(:a => 1))
end
