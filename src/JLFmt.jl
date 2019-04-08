module JLFmt

using CSTParser
import CSTParser.Tokenize.Tokens

export format

function file_line_ranges(text::String)
    ranges = UnitRange{Int}[]
    lit_strings = Dict{Int, Tuple{Int,Int,String}}()
    for t in CSTParser.Tokenize.tokenize(text)
        if t.kind == Tokens.WHITESPACE
            offset = t.startbyte
            for c in t.val
                if c == '\n'
                    s = length(ranges) > 0 ? last(ranges[end]) + 1 : 1
                    push!(ranges, s:offset+1)
                end
                offset += 1
            end
        elseif t.kind == Tokens.ENDMARKER
            s = length(ranges) > 0 ? last(ranges[end]) + 1 : 1
            push!(ranges, s:t.startbyte)
        elseif (t.kind == Tokens.TRIPLE_STRING || t.kind == Tokens.STRING) && t.startpos[1] != t.endpos[1]
            offset = t.startbyte
            nls = findall(x -> x == '\n', t.val)
            for nl in nls
                s = length(ranges) > 0 ? last(ranges[end]) + 1 : 1
                push!(ranges, s:offset+nl)
            end
        elseif t.kind == Tokens.COMMENT
            # @info "comment token" t
        end

        if (t.kind == Tokens.TRIPLE_STRING || t.kind == Tokens.STRING)
            lit_strings[t.startbyte] = (t.startpos[1], t.endpos[1], t.val)
        end
    end
    ranges, lit_strings
end

struct Document
    text::String
    ranges::Vector{UnitRange{Int}}
    # mapping the offset in the file to the raw literal
    # string and what lines it starts and ends at.
    lit_strings::Dict{Int, Tuple{Int, Int, String}}
    # inline_commments::Vector{LitString}
end
Document(s::String) = Document(s, file_line_ranges(s)...)

mutable struct State
    doc::Document
    indent_size::Int
    indents::Int
    offset::Int
    line_offset::Int
    print_width::Int
end

@inline nspaces(s::State) = s.indent_size * s.indents

@inline function cursor_loc(s::State, offset::Int)
    for (l, r) in enumerate(s.doc.ranges)
        if offset in r
            return (l, offset - first(r) + 1, length(r))
        end
    end
    error("Indexing range 1 - $(last(s.doc.ranges[end])), index used = $(offset)")
end
@inline cursor_loc(s::State) = cursor_loc(s, s.offset)

include("pretty.jl")
include("nest.jl")
include("print.jl")

function format(text::String; indent_size=4, print_width=80)
    if isempty(text)
        return text
    end
    d = Document(text)
    s = State(d, indent_size, 0, 1, 0, print_width)
    x = CSTParser.parse(text, true)
    t = pretty(x, s)
    nest!(t, s)

    io = IOBuffer()
    # Print comments and whitespace before any code.
    if t.startline > 1
        print_tree(io, NotCode(1, t.startline-1, 0), s)
    end
    print_tree(io, t, s)
    # Print comments and whitespace after any code.
    if t.endline < length(s.doc.ranges)
        print_tree(io, newline, s)
        print_tree(io, NotCode(t.endline+1, length(s.doc.ranges), 0), s)
    end

    String(take!(io))
end

end # module
