# frozen_string_literal: true

unless system("latex -version", [:out, :err]=>File::NULL)
    STDERR.puts "You are missing a TeX distribution. Please install:"
    STDERR.puts "  MiKTeX or TeX Live"
    raise "Missing TeX distribution"
end

require "jekyll/cache"

require "jekyll-t4j/engines/dvisvgm"
require "jekyll-t4j/engines/katex"

module Jekyll::T4J
    class Engine
        @@cache_katex = Jekyll::Cache.new "Jekyll::T4J::Katex"
        @@cache_dvisvgm = Jekyll::Cache.new "Jekyll::T4J::Dvisvgm"

        @@correction = File.read File.join(__dir__, "engines", "correction.tex")

        def initialize(merge_callback)
            @merger = merge_callback
        end

        def header
            result = String.new

            result << "<link rel=\"stylesheet\" href=\"https://unpkg.com/katex@#{KATEX_VERSION}/dist/katex.min.css\">" if @has_katex
            result << "<style>.katex-ext-d{border-radius:0px;display:block;margin:0 auto;}.katex-ext-i{border-radius:0px;display:inline;vertical-align:middle;}</style>" if @has_katex_ext

            result
        end

        def render(snippet, displayMode)
            return "" if (snippet = snippet.strip).empty?

            # try katex first
            cached = @@cache_katex.getset(displayMode.to_s + snippet) {
                Engine.katex_raw(snippet, {displayMode:, strict: true}) or "nil"
            }
            proc_by_katex = cached != "nil"

            # otherwise we turn to dvisvgm
            cached = @@cache_dvisvgm.getset(Jekyll::T4J.cfg_pkgs + snippet) {
                Engine.dvisvgm_raw(
                <<~HEREDOC
                    \\documentclass{article}
                    #{Jekyll::T4J.cfg_pkgs}
                    #{@@correction}
                    \\begin{document}
                    \\pagenumbering{gobble}
                    #{snippet}
                    \\end{document}
                HEREDOC
                )
            } if not proc_by_katex

            # return the result
            if proc_by_katex then
                @has_katex = true

                cached
            else
                @has_katex_ext = true

                "<img src=\"#{@merger.(cached, "svg")}\" class=\"#{
                    displayMode ? "katex-ext-d" : "katex-ext-i"
                }\" style=\"height:#{
                    (cached[/height='(\S+?)pt'/, 1].to_f * 0.1).to_s[/\d+\.\d{1,4}/]
                }em\">"
            end
        end
    end
end