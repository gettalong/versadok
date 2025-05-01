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

  class Renderer

    def initialize(context)
      @context = context
    end

    def render(root)
      render_node(root)
    end

    private

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
      when :extension_block then render_extension_block(node)
      when :inline_extension then render_inline_extension(node)
      else
        raise "Unsupported node type #{node.type}"
      end
    end

    def render_root(node)
      render_children(node)
    end

    def render_blank(blank)
    end

    def render_children(node)
      node.children.each {|child| render_node(child) }
    end

    alias_method :render_paragraph, :render_root
    alias_method :render_header, :render_root
    alias_method :render_blockquote, :render_root
    alias_method :render_list, :render_root
    alias_method :render_list_item, :render_root
    alias_method :render_span, :render_root
    alias_method :render_link, :render_root
    alias_method :render_strong, :render_root
    alias_method :render_emphasis, :render_root
    alias_method :render_subscript, :render_root
    alias_method :render_superscript, :render_root

    alias_method :render_text, :render_blank
    alias_method :render_soft_break, :render_blank
    alias_method :render_hard_break, :render_blank
    alias_method :render_verbatim, :render_blank
    alias_method :render_extension_block, :render_blank
    alias_method :render_inline_extension, :render_blank

  end

end
