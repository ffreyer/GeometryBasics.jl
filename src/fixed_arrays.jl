
function unit(::Type{T}, i::Integer) where T <: StaticVector
    T(ntuple(Val(length(T))) do j
        ifelse(i == j, 1, 0)
    end)
end

macro fixed_vector(name, parent)
    esc(quote

        struct $(name){S, T} <: $(parent){S, T}
            data::NTuple{S, T}

            function $(name){S, T}(x::NTuple{S,T}) where {S, T}
                new{S, T}(x)
            end

            function $(name){S, T}(x::NTuple{S,Any}) where {S, T}
                new{S, T}(StaticArrays.convert_ntuple(T, x))
            end
        end

        size_or(::Type{$(name)}, or) = or
        eltype_or(::Type{$(name)}, or) = or
        eltype_or(::Type{$(name){S, T} where S}, or) where {T} = T
        eltype_or(::Type{$(name){S, T} where T}, or) where {S} = or
        eltype_or(::Type{$(name){S, T}}, or) where {S, T} = T

        size_or(::Type{$(name){S, T} where S}, or) where {T} = or
        size_or(::Type{$(name){S, T} where T}, or) where {S} = Size{(S,)}()
        size_or(::Type{$(name){S, T}}, or) where {S, T} = (S,)

        # Array constructor
        function $(name){S}(x::AbstractVector{T}) where {S, T}
            @assert S <= length(x)
            $(name){S, T}(ntuple(i-> x[i], Val(S)))
        end

        function $(name){S, T1}(x::AbstractVector{T2}) where {S, T1, T2}
            @assert S <= length(x)
            $(name){S, T1}(ntuple(i-> T1(x[i]), Val(S)))
        end

        function $(name){S, T}(x) where {S, T}
            $(name){S, T}(ntuple(i-> T(x), Val(S)))
        end


        $(name){S}(x::T) where {S, T} = $(name){S, T}(ntuple(i-> x, Val(S)))
        $(name){1, T}(x::T) where T = $(name){1, T}((x,))
        $(name)(x::NTuple{S}) where {S} = $(name){S}(x)
        $(name)(x::T) where {S, T <: Tuple{Vararg{Any, S}}} = $(name){S, StaticArrays.promote_tuple_eltype(T)}(x)

        $(name){S}(x::T) where {S, T<:Tuple} = $(name){S, StaticArrays.promote_tuple_eltype(T)}(x)
        $(name){S, T}(x::StaticVector) where {S, T} = $(name){S, T}(Tuple(x))

        @generated function (::Type{$(name){S, T}})(x::$(name)) where {S, T}
            idx = [:(x[$i]) for i = 1:S]
            quote
                $($(name)){S, T}($(idx...))
            end
        end

        @generated function Base.convert(::Type{$(name){S, T}}, x::$(name)) where {S, T}
            idx = [:(x[$i]) for i = 1:S]
            quote
                $($(name)){S, T}($(idx...))
            end
        end

        @generated function (::Type{SV})(x::StaticVector) where SV <: $(name)
            len = size_or(SV, size(x))[1]
            if length(x) == len
                :(SV(Tuple(x)))
            elseif length(x) > len
                elems = [:(x[$i]) for i = 1:len]
                :(SV($(Expr(:tuple, elems...))))
            else
                error("Static Vector too short: $x, target type: $SV")
            end
        end

        Base.@pure StaticArrays.Size(::Type{$(name){S, Any}}) where {S} = Size(S)
        Base.@pure StaticArrays.Size(::Type{$(name){S, T}}) where {S,T} = Size(S)

        Base.@propagate_inbounds function Base.getindex(v::$(name){S, T}, i::Int) where {S, T}
            v.data[i]
        end

        Base.Tuple(v::$(name)) = v.data
        Base.convert(::Type{$(name){S, T}}, x::NTuple{S, T}) where {S, T} = $(name){S, T}(x)
        function Base.convert(::Type{$(name){S, T}}, x::Tuple) where {S, T}
            $(name){S, T}(convert(NTuple{S, T}, x))
        end

        @generated function StaticArrays.similar_type(::Type{SV}, ::Type{T}, s::Size{S}) where {SV <: $(name), T, S}
            if length(S) === 1
                $(name){S[1], T}
            else
                StaticArrays.default_similar_type(T,s(),Val{length(S)})
            end
        end

    end)
end

abstract type AbstractPoint{Dim, T} <: StaticVector{Dim, T} end
@fixed_vector Point AbstractPoint
@fixed_vector Vec StaticVector


const Mat = SMatrix
const VecTypes{N, T} = Union{StaticVector{N, T}, NTuple{N, T}}
const Vecf0{N} = Vec{N, Float32}
const Pointf0{N} = Point{N, Float32}
Base.isnan(p::StaticVector) = any(x-> isnan(x), p)

#Create constes like Mat4f0, Point2, Point2f0
for i=1:4
    for T=[:Point, :Vec]
        name = Symbol("$T$i")
        namef0 = Symbol("$T$(i)f0")
        @eval begin
            const $name = $T{$i}
            const $namef0 = $T{$i, Float32}
            export $name
            export $namef0
        end
    end
    name = Symbol("Mat$i")
    namef0 = Symbol("Mat$(i)f0")
    @eval begin
        const $name{T} = $Mat{$i,$i, T, $(i*i)}
        const $namef0 = $name{Float32}
        export $name
        export $namef0
    end
end

export Mat, Vec, Point, unit
export Vecf0, Pointf0
