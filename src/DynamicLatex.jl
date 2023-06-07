module DynamicLatex

export @objects, write_texdefs, write_symbols_table, @bb_str, @rm_str

using DynamicObjects

macro bb_str(x) raw"\mathbb{"*x*"}" end
macro rm_str(x) raw"\mathrm{"*x*"}" end

struct Head{T} end
macro Head_str(x) Head{Symbol(x)} end
tex(what::AbstractString) = what
tex(what::Symbol) = string(what)
@dynamic_type Latex
description(what) = ""
(what::Latex)(args...) = Expression(:call, (what, args...))
Base.:^(lhs::Latex, rhs) = Expression(:call, (:^, lhs, rhs))
times(lhs, rhs) = Expression(:call, (raw"\times", lhs, rhs))
texdef(what::Latex) = what.texnargs > 0 ? """
\\newcommand{$(what.tex)}$(what.texargs){$(what.texbody)}
\\newcommand{$(what.dtex)}$(what.texargs){$(what.description)}
""" : """
\\newcommand{$(what.tex)}$(what.texargs){$(what.texbody)}
\\newcommand{$(what.dtex)}$(what.texargs){$(what.description)}
\\newcommand{$(what.itex)}{$(what.description) $(what.md_body)}
\\newcommand{$(what.etex)}{$(what.description) $(what.emd_body)}
\\newcommand{$(what.tex)is}{$(what.md_body) is the $(what.description)}
"""
@dynamic_object Object <: Latex name value description=""
tex(what::Object) = "\\$(what.name)"
dtex(what::Object) = "\\d$(what.name)"
itex(what::Object) = "\\i$(what.name)"
etex(what::Object) = "\\E$(what.name)"
texbody(what::Object) = tex(what.value)
inline_math(args...) = raw"$"*join(tex.(args))*raw"$"
curly_wrap(args...) = "{"*join(tex.(args))*"}"
md_body(what::Object) = inline_math(what.value)
emd_body(::Head, what::Object) = missing
function emd_body(what::Object)
    for key in keys(what.nt)
        rv = emd_body(Head{key}(), what)
        !ismissing(rv) && return rv
    end
    what.md_body 
end
emd_body(::Head"domain", what::Object) = inline_math(what.value, raw"\in", what.domain)
emd_body(::Head"maps", what::Object) = inline_math(what.value, ":", what.maps[1],raw"\to", what.maps[2])
texnargs(what::Object) = maximum(
    [
        parse(Int, m[2:end]) 
        for m in SubString.(what.texbody, findall(r"#[0-9]+", what.texbody))
    ],
    init=0
)
texargs(what::Object) = what.texnargs > 0 ? "[$(what.texnargs)]" : ""

@dynamic_object Expression <: Latex head args
targs(what::Expression) = tex.(what.args)
dispatchable(what) = what
dispatchable(what::Symbol) = Head{what}()
dispatchable(what::AbstractString) = Head{Symbol(what)}()
dispatchable(what::Head) = what
dispatchable_args(what::Expression) = vcat(dispatchable(what.head), dispatchable.(what.args)...)
tex(what::Expression) = tex(what, what.dispatchable_args...)
tex(what::Expression, ::Head"call", args...) = (
    targs = what.targs;
    targs[1] * join(curly_wrap.(targs[2:end]))
)
tex(what::Expression, ::Head"call", ::Head, args...) = (
    targs = what.targs;
    "{$(targs[2])}$(targs[1]){$(targs[3])}"
)
# tex(what::Expression, ::Head"call", head, args...)
# function tex(what::Expression) 
#     if what.head == :call

#         "$(what.targs[1]){$(what.targs[2])}"
#     else
#         "NOT IMPLEMENTED!"
#         # "$(what.targs[1])^{$(what.targs[2])}"
#     end
# end
precomputed(what::Object) = update(what, :tex, :dtex, :itex, :etex, :texbody, :md_body, :emd_body, :texnargs, :texargs)

description_str_f(description::AbstractString) = description
function description_str_f(description::Expr)
    if description.head == :string
        Expr(:string, description_str_f.(description.args)...)
    else
        description
    end
end
description_str_f(description::Symbol) = :($(esc(description)).description)
function object_f(objects_list, name, value, description="")
    elist = esc(objects_list)
    sname = String(name)
    ename = esc(name)
    evalue = esc(value)
    quote
        push!(
            $elist, 
            Object($sname, $evalue, $(description_str_f(description))).precomputed
        )
        $ename = $elist[end]
    end
end
function object_f(objects_list, name, value, description, kwargs)
    elist = esc(objects_list)
    sname = String(name)
    ename = esc(name)
    evalue = esc(value)
    ekwargs = esc(kwargs)
    quote
        push!(
            $elist, 
            Object($sname, $evalue, $(description_str_f(description)); $ekwargs...)
        )
        $ename = $elist[end]
    end
end
# object_f(name, value, description, ekwargs::NamedTuple) = object_f(name, value, description; ekwargs...)
# object_f(name::Symbol) = object_f(name, )
macro object(objects_list, name, value, description="")
    object_f(objects_list, name, value, description)
end
function objects_f(objects_list, list)
    rv = quote end
    for row in list.args
        rv.args = vcat(rv.args, object_f(objects_list, row.args...).args)
    end
    rv
end
macro objects(objects_list, list)
    objects_f(objects_list, list)
end

texdefs(objects) = join(texdef.(objects))
write_texdefs(tex_path, objects) = open(tex_path, "w") do fd
    write(fd, texdefs(objects))
end
function symbols_table(objects)
    rv = """
symbol|meaning|latex
-|---|-
"""
    for object in objects
        object.description == "" && continue
        line = if object.texnargs > 0
            !hasproperty(object, :display_args) && continue
            t = tex(object(object.display_args...))
            d = "$(object.dtex)$(join(curly_wrap.(object.display_args)))"
            "$(inline_math(t))|$(d)|`$(t)`"
        else
            "$(object.emd_body)|$(object.description)|`$(object.tex)`"
        end
        # object.texnargs > 0 && continue
        rv = rv * line * "\n"
    end
    rv
end 
write_symbols_table(md_path, objects) = open(md_path, "w") do fd
    write(fd, symbols_table(objects))
end

end