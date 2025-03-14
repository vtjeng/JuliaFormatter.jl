for f in [
    :n_call!,
    :n_curly!,
    :n_ref!,
    :n_macrocall!,
    :n_typedcomprehension!,
    :n_tuple!,
    :n_braces!,
    :n_parameters!,
    :n_invisbrackets!,
    :n_comprehension!,
    :n_vcat!,
    :n_typedvcat!,
    :n_bracescat!,
    :n_generator!,
    :n_filter!,
    :n_flatten!,
    :n_using!,
    :n_export!,
    :n_import!,
    :n_chainopcall!,
    :n_comparison!,
    :n_for!,
    #:n_vect!
]
    @eval function $f(ss::SciMLStyle, fst::FST, s::State)
        style = getstyle(ss)
        if s.opts.yas_style_nesting
            $f(YASStyle(style), fst, s)
        else
            $f(DefaultStyle(style), fst, s)
        end
    end
end

function n_binaryopcall!(ss::SciMLStyle, fst::FST, s::State; indent::Int = -1)
    style = getstyle(ss)
    line_margin = s.line_offset + length(fst) + fst.extra_margin
    if line_margin > s.opts.margin &&
       fst.ref !== nothing &&
       CSTParser.defines_function(fst.ref[])
        transformed = short_to_long_function_def!(fst, s)
        transformed && nest!(style, fst, s)
    end

    if findfirst(n -> n.typ === PLACEHOLDER, fst.nodes) !== nothing
        n_binaryopcall!(DefaultStyle(style), fst, s; indent = indent)
        return
    end

    start_line_offset = s.line_offset
    walk(increment_line_offset!, (fst.nodes::Vector)[1:end-1], s, fst.indent)
    nest!(style, fst[end], s)
end

function n_functiondef!(ss::SciMLStyle, fst::FST, s::State)
    style = getstyle(ss)
    if s.opts.yas_style_nesting
        nest!(
            YASStyle(style),
            fst.nodes::Vector,
            s,
            fst.indent,
            extra_margin = fst.extra_margin,
        )
    else
        nest!(
            DefaultStyle(style),
            fst.nodes::Vector,
            s,
            fst.indent,
            extra_margin = fst.extra_margin,
        )

        base_indent = fst.indent
        closers = FST[]
        f = (fst::FST, s::State) -> begin
            if is_closer(fst) && fst.indent == base_indent
                push!(closers, fst)
            end
            fst.indent += s.opts.indent
            return nothing
        end
        lo = s.line_offset
        walk(f, fst[3], s)
        s.line_offset = lo
        for c in closers
            c.indent -= s.opts.indent
        end
    end
end

function n_macro!(ss::SciMLStyle, fst::FST, s::State)
    n_functiondef!(ss, fst, s)
end
