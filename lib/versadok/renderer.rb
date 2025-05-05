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

  # A Renderer instance takes an abstract syntax tree of Node objects and turns it into a result
  # document.
  #
  # This base renderer provides minimal default implementations for all rendering methods. It is
  # structured like this:
  #
  # * The main entry point for rendering any node via a renderer instance is the #render
  #   method. This method just delegates to #render_node by default but can be used to e.g. set up
  #   needed objects.
  #
  # * The #render_node method is responsible for calling the appropriate type-specific node
  #   rendering methods. For example, the root node is rendered via #render_root, the header node
  #   via #render_header and so on.
  #
  # * Each of these node type specific rendering methods has a default implementation. Those node
  #   types that are essentially collectons of nodes will defer to #render_children, all others will
  #   just do nothing.
  #
  # * The method #render_children goes through each child in turn and calls #render_node for it.
  #
  # Subclasses can and should override any of these methods based on their needs.
  class Renderer

    # The rendering context (see Context).
    attr_reader :context

    # Creates a new renderer instance for the given +context+.
    def initialize(context)
      @context = context
    end

    # Renders the given +node+ (usually the :root node).
    def render(node)
      render_node(node)
    end

    private

    # Renders a single +node+.
    #
    # This base method defers rendering to the node type specific method of the form +render_TYPE+.
    def render_node(node)
      case node.type
      when :root then render_root(node)
      when :blank then render_blank(node)
      when :paragraph then render_paragraph(node)
      when :header then render_header(node)
      when :blockquote then render_blockquote(node)
      when :list then render_list(node)
      when :list_item then render_list_item(node)
      when :text then render_text(node)
      when :soft_break then render_soft_break(node)
      when :hard_break then render_hard_break(node)
      when :verbatim then render_verbatim(node)
      when :span then render_span(node)
      when :link then render_link(node)
      when :strong then render_strong(node)
      when :emphasis then render_emphasis(node)
      when :subscript then render_subscript(node)
      when :superscript then render_superscript(node)
      when :block_extension then render_block_extension(node)
      when :inline_extension then render_inline_extension(node)
      else
        raise "Unsupported node type #{node.type}"
      end
    end

    # Implements the general case of rendering a node having child nodes.
    def render_root(node)
      render_children(node)
    end

    # Implements the general case of rendering a node without children.
    def render_blank(blank)
    end

    # Renders all children of +node+ in-order via #render_node.
    def render_children(node)
      node.children.each {|child| render_node(child) }
    end

    alias_method :render_paragraph, :render_root #:nodoc:
    alias_method :render_header, :render_root #:nodoc:
    alias_method :render_blockquote, :render_root #:nodoc:
    alias_method :render_list, :render_root #:nodoc:
    alias_method :render_list_item, :render_root #:nodoc:
    alias_method :render_span, :render_root #:nodoc:
    alias_method :render_link, :render_root #:nodoc:
    alias_method :render_strong, :render_root #:nodoc:
    alias_method :render_emphasis, :render_root #:nodoc:
    alias_method :render_subscript, :render_root #:nodoc:
    alias_method :render_superscript, :render_root #:nodoc:

    alias_method :render_text, :render_blank #:nodoc:
    alias_method :render_soft_break, :render_blank #:nodoc:
    alias_method :render_hard_break, :render_blank #:nodoc:
    alias_method :render_verbatim, :render_blank #:nodoc:
    alias_method :render_block_extension, :render_blank #:nodoc:
    alias_method :render_inline_extension, :render_blank #:nodoc:

  end

end
