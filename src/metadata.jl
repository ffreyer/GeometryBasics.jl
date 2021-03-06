#=
Helper functions that works around the fact, that there is no generic
Table interface for this functionality. Once this is in e.g. Tables.jl,
it should be removed from GeometryBasics!
=#

function attributes(hasmeta)
    return Dict((name => getproperty(hasmeta, name) for name in propertynames(hasmeta)))
end

"""
    getcolumns(t, colnames::Symbol...)

Gets a column from any Array like (Table/AbstractArray).
For AbstractVectors, a column will be the field names of the element type.
"""
function getcolumns(tablelike, colnames::Symbol...)
    return getproperty.((tablelike,), colnames)
end

getcolumn(t, colname::Symbol) = getcolumns(t, colname)[1]

"""
    MetaType(::Type{T})

Returns the Meta Type corresponding to `T`
E.g:
```julia
MetaType(Point) == PointMeta
"""
MetaType(::Type{T}) where T = error("No Meta Type for $T")

"""
    MetaFree(::Type{T})

Returns the original type containing no metadata for `T`
E.g:
```julia
MetaFree(PointMeta) == Point
"""
MetaFree(::Type{T}) where T = error("No meta free Type for $T")

"""
    meta(x::MetaObject)

Returns the metadata of `x`
"""
meta(x::T) where T = error("$T has no meta!")

metafree(x::T) where T = x

macro meta_type(name, mainfield, supertype, params...)
    MetaName = Symbol("$(name)Meta")
    field = QuoteNode(mainfield)
    NoParams = Symbol("$(MetaName)NoParams")
    expr = quote
        struct $MetaName{$(params...), Typ <: $supertype{$(params...)}, Names, Types} <: $supertype{$(params...)}
            main::Typ
            meta::NamedTuple{Names, Types}
        end

        const $NoParams{Typ, Names, Types} = $MetaName{$(params...), Typ, Names, Types} where {$(params...)}

        function Base.getproperty(x::$MetaName{$(params...), Typ, Names, Types}, field::Symbol) where {$(params...), Typ, Names, Types}
            field === $field && return getfield(x, :main)
            field === :main && return getfield(x, :main)
            Base.sym_in(field, Names) && return getfield(getfield(x, :meta), field)
            error("Field $field not part of Element")
        end

        GeometryBasics.MetaType(T::Type{<: $supertype}) = $MetaName{T}
        function GeometryBasics.MetaType(
                ST::Type{<: $supertype{$(params...)}},
                ::Type{NamedTuple{Names, Types}}) where {$(params...), Names, Types}
            return $MetaName{$(params...), ST, Names, Types}
        end


        GeometryBasics.MetaFree(::Type{<: $MetaName{Typ}}) where Typ = Typ
        GeometryBasics.MetaFree(::Type{<: $MetaName}) = $name
        GeometryBasics.metafree(x::$MetaName) = getfield(x, :main)
        GeometryBasics.metafree(x::AbstractVector{<: $MetaName}) = getcolumns(x, $field)[1]
        GeometryBasics.meta(x::$MetaName) = getfield(x, :meta)
        GeometryBasics.meta(x::AbstractVector{<: $MetaName}) = getcolumns(x, :meta)[1]

        function GeometryBasics.meta(main::$supertype; meta...)
            isempty(meta) && return elements # no meta to add!
            return $MetaName(main; meta...)
        end

        function GeometryBasics.meta(elements::AbstractVector{T}; meta...) where T <: $supertype
            isempty(meta) && return elements # no meta to add!
            n = length(elements)
            for (k, v) in meta
                if v isa AbstractVector
                    mn = length(v)
                    mn != n && error("Metadata array needs to have same length as data.
                    Found $(n) data items, and $mn metadata items")
                else
                    error("Metadata needs to be an array with the same length as data items. Found: $(typeof(v))")
                end
            end
            nt = values(meta)
            # get the first element to get the per element named tuple type
            ElementNT = typeof(map(first, nt))

            return StructArray{MetaType(T, ElementNT)}(($(mainfield) = elements, nt...))
        end

        function (MT::Type{<: $MetaName})(args...; meta...)
            nt = values(meta)
            obj = MetaFree(MT)(args...)
            return MT(obj, nt)
        end

        function StructArrays.staticschema(::Type{$MetaName{$(params...), Typ, Names, Types}}) where {$(params...), Typ, Names, Types}
            NamedTuple{($field, Names...), Base.tuple_type_cons(Typ, Types)}
        end

        function StructArrays.createinstance(
                ::Type{$MetaName{$(params...), Typ, Names, Types}},
                metafree, args...
            ) where {$(params...), Typ, Names, Types}
            $MetaName(metafree, NamedTuple{Names, Types}(args))
        end
    end
    return esc(expr)
end

@meta_type(Point, position, AbstractPoint, Dim, T)
Base.getindex(x::PointMeta, idx::Int) = getindex(metafree(x), idx)

@meta_type(NgonFace, ngon, AbstractNgonFace, N, T)
Base.getindex(x::NgonFaceMeta, idx::Int) = getindex(metafree(x), idx)

@meta_type(SimplexFace, simplex, AbstractSimplexFace, N, T)
Base.getindex(x::SimplexFaceMeta, idx::Int) = getindex(metafree(x), idx)

@meta_type(Polygon, polygon, AbstractPolygon, N, T)
