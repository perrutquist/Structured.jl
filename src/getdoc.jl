"""
    _getdoc(T)

Get the docstring for a type, as a text string.
Returns `nothing` unless exactly one docstring was found.
(Relies on undocumented Julia internals)
"""
function _getdoc(::Type{T}) where {T}
    try
        only(only(Docs.doc(T).meta[:results]).text)
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
