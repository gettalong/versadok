require_relative 'versadok/data_dir'
require_relative 'versadok/node'
require_relative 'versadok/extension'
require_relative 'versadok/context'
require_relative 'versadok/parser'
require_relative 'versadok/renderer'

# VersaDok is both a lightweight markup language for creating documents as well as a library to
# actually convert such documents.
#
# == Library
#
# The small API of the library is extensively documented and simple to use:
#
#  require 'versadok'
#
#  # Create the context for storing needed information
#  context = VersaDok::Context.new
#
#  # Parse the document into an AST
#  ast = VersaDok::Parser.new(context).parse(ARGF.read).finish
#
#  # Render the AST into an output document
#  puts VersaDok::HTMLRenderer.new(context).render(ast)
#
#
# == Syntax
#
# The syntax us VersaDok is similar to markup languages like Markdown and AsciiDoc:
#
#   This is a _small_ example of *VersaDok*!
#
#   It works similar to languages like
#
#   * Markdown and
#   * AsciiDoc.
#
#   > Shoutout to all other markup languages!
#
# The complete syntax is available at the VersaDok homepage.
module VersaDok
end
