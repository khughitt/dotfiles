#
# Julia config
#

# load OhMyREPL
import REPL

atreplinit() do repl
    repl.interface = REPL.setup_interface(repl)
    Base.active_repl.interface.modes[1].prompt_prefix = "\e[32m"
end

# Use terminal slots so Noctalia palette changes affect a running REPL.
using OhMyREPL
using Crayons
import OhMyREPL: Passes.SyntaxHighlighter

scheme = SyntaxHighlighter.ColorScheme()
SyntaxHighlighter.string!(scheme, Crayon(foreground = :green))
SyntaxHighlighter.symbol!(scheme, Crayon(foreground = :red))
SyntaxHighlighter.comment!(scheme, Crayon(foreground = :dark_gray))
SyntaxHighlighter.call!(scheme, Crayon(foreground = :blue))
SyntaxHighlighter.op!(scheme, Crayon(foreground = :magenta))
SyntaxHighlighter.keyword!(scheme, Crayon(foreground = :red))
SyntaxHighlighter.error!(scheme, Crayon(foreground = :light_red))
SyntaxHighlighter.argdef!(scheme, Crayon(foreground = :yellow))
SyntaxHighlighter.macro!(scheme, Crayon(foreground = :magenta))
SyntaxHighlighter.number!(scheme, Crayon(foreground = :yellow))
SyntaxHighlighter.function_def!(scheme, Crayon(foreground = :light_gray))
SyntaxHighlighter.add!("Noctalia", scheme)
colorscheme!("Noctalia")
OhMyREPL.enable_pass!("RainbowBrackets", false)
