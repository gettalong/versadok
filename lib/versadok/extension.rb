# -*- encoding: utf-8; frozen_string_literal: true -*-
#
#--
# This file is part of VersaDok.
#
# VersaDok - Versatile document creation markup and library
# Copyright (C) 2025 Thomas Leitner <t_leitner@gmx.at>
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

module VersaDok

  # The base implementation of an extension.
  #
  # Extensions allow adding functionality to VersaDok and are used by the Parser and the Renderer.
  #
  # == Parsing
  #
  # When the parser encounters a block extension marker, it uses Context#extension to get the
  # associated extension and creates an appropriate Node instance.
  #
  # The #parse_content? method defines whether the content of the block extension is parsed by the
  # extension itself or as VersaDok block-level elements. In the former case each line is passed to
  # #parse_line and at the end #parsing_finished! is called. This allows embedding foreign content
  # into a VersaDok document.
  #
  # == Rendering
  #
  # When the renderer walks the created AST, it uses the extension name stored in inline and block
  # extension nodes to retrieve the associated extension instance. Then #render is called so that
  # the extension can perform its function.
  class Extension

    # Specifies one or more names under which the extension can be accessed.
    #
    # The names can be any strings and the special name :default. The latter is used when the parser
    # or renderer encounters an unknown extension name.
    #
    # The base class doesn't define any names.
    def self.extension_names = []

    # Creates a new Extension instance with the given Context.
    def initialize(context)
      @context = context
    end

    # Returns +true+ if the extension itself should parse the content of a block extension element.
    #
    # Also see: #parse_line and #parsing_finished!
    def parse_content?
      false
    end

    # Parses a single +line+ of the content of the block extension.
    #
    # How this line is handled is completely up to the extension itself: It can discard the line,
    # store the line until all lines are read, or process each line individually.
    #
    # Once this method has been called for all lines, the #parsing_finished! method is called.
    #
    # Also see: #parse_content?
    def parse_line(line)
    end

    # Handles finalizing the parsing of the input lines.
    #
    # This method is called after #parse_line has been called for all lines of the block
    # extension.
    #
    # Also see: #parse_content?
    def parsing_finished!
    end

    # Renders the given inline or block extension +node+ with the given +renderer+.
    #
    # How the rendering is done depends on the specific renderer. The simplest case is calling
    # renderer.render(node) with a newly created Node instance of a standard type. The renderer
    # might also provide a special interface for extensions to do custom rendering.
    def render(node, renderer)
    end

  end

end
