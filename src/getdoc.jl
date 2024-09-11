"""
    _getdoc(T)

Get the docstring for a user type, as a text string.
Returns `nothing` unless exactly one docstring was found.
Also returns `nothing` for types in Base/Core.
(Relies on undocumented Julia internals)
"""
function _getdoc(::Type{T}) where {T}
    try
        T.name.module in (Base, Core) ? nothing : only(only(Docs.doc(T).meta[:results]).text)
    catch
        nothing
    end
end

"""
    _getdoc(T, Symbol)

Get the docstring for a field of a type, as a text string.
Returns `nothing` unless exactly one docstring was found.
(Relies on undocumented Julia internals)
"""
function _getdoc(::Type{T}, field::Symbol) where {T}
    try
        only(Docs.doc(T).meta[:results]).data[:fields][field]
    catch
        nothing
    end
end
