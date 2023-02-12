# frozen_string_literal: true

require "tmpdir"
require "open3"

module Jekyll::T4J
    class Engine
        @@_dvisvgm_tex_ = File.read(File.join(__dir__, "dvisvgm.tex"))

        def self.dvisvgm_raw(src, displayMode, pkgs)
            # setup: write 'src' to 'content.tex'
            pwd = Dir.mktmpdir
            File.write "#{pwd}/content.tex", <<~HEREDOC
                \\documentclass{article}
                #{pkgs}
                #{@@_dvisvgm_tex_}
                \\begin{document}
                \\pagenumbering{gobble}
                #{displayMode = displayMode ? "$$" : "$"}
                #{src}
                #{displayMode}
                \\end{document}
            HEREDOC

            shell = ->(cmd) {
                log, s = Open3.capture2e(cmd, :chdir => pwd)
                raise log if not s.success?
            }

            # call 'latex' to compile: tex->dvi
            shell.("latex -halt-on-error -quiet content")
            shell.("latex -halt-on-error -quiet content")
            # call 'dvisvgm' to convert dvi to svg
            shell.("dvisvgm -n -e -v 3 content")

            # fetch result
            File.read "#{pwd}/content.svg"
        ensure
            FileUtils.remove_entry pwd if pwd
        end
    end
end