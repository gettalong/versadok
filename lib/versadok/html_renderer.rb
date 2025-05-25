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

require_relative 'renderer'

module VersaDok

  # The HTML renderer takes a VersaDok AST and returns an HTML representation.
  class HTMLRenderer < Renderer

    # Renders the given +node+ into an appropriate HTML fragment.
    def render(node)
      @out = +''
      super
      @out
    end

    private

    # Renders a paragraph.
    def render_paragraph(para)
      @out << "<p#{html_attributes(para.attributes)}>"
      super
      @out << "</p>\n"
    end

    # Renders a header.
    def render_header(header)
      el_name = case header[:level]
                when 1 then 'h1'
                when 2 then 'h2'
                when 3 then 'h3'
                when 4 then 'h4'
                when 5 then 'h5'
                else 'h6'
                end
      @out << "<#{el_name}#{html_attributes(header.attributes)}>"
      super
      @out << "</#{el_name}>\n"
    end

    # Renders a blockquote.
    def render_blockquote(bq)
      @out << "<blockquote#{html_attributes(bq.attributes)}>\n"
      super
      @out << "</blockquote>\n"
    end

    # Renders an ordered or unordered list.
    #
    # See: #render_list_item
    def render_list(list)
      el_name = (list[:marker] == :decimal ? 'ol' : 'ul')
      if list[:marker] == :decimal && list[:start] && list[:start] != 1
        overrides = {'start' => list[:start]}
      end
      @out << "<#{el_name}#{html_attributes(list.attributes, overrides)}>\n"
      super
      @out << "</#{el_name}>\n"
    end

    # Renders a single list item within a list.
    #
    # See: #render_list
    def render_list_item(list_item)
      @out << "<li#{html_attributes(list_item.attributes)}>\n"
      super
      @out << "</li>\n"
    end

    # Renders a code block.
    def render_code_block(code_block)
      @out << "<pre#{html_attributes(code_block.attributes)}><code>#{code_block.content}</code></pre>\n"
    end

    # Renders a text node.
    #
    # The method makes sure that all necessary characters are escaped.
    def render_text(text)
      @out << escape_html(text.content)
    end

    # Renders a soft-break node.
    def render_soft_break(_node)
      @out << "\n"
    end

    # Renders a hard-break node.
    def render_hard_break(_node)
      @out << "<br />\n"
    end

    # Renders verbatim text.
    def render_verbatim(verbatim)
      @out << "<code#{html_attributes(verbatim.attributes)}>#{escape_html(verbatim.content)}</code>"
    end

    ['span', 'strong', ['emphasis', 'em'], ['subscript', 'sub'],
     ['superscript', 'sup']].each do |node_type, el = node_type|
      class_eval <<~METHOD_DEF, __FILE__, __LINE__ + 1
      def render_#{node_type}(node)
        @out << "<#{el}\#{html_attributes(node.attributes)}>"
        super
        @out << "</#{el}>"
      end
      METHOD_DEF
    end

    # Renders a link node.
    def render_link(link)
      overrides = if link[:destination]
                    {'href' => link[:destination]}
                  elsif (dest = @context.references[link[:reference]])
                    {'href'=> dest }
                  end
      @out << "<a#{html_attributes(link.attributes, overrides)}>"
      super
      @out << "</a>"
    end

    # Returns the HTML representation of the attributes +attr+.
    #
    # The argument +overrides+ can be used to override any of the keys in attributes. This allows
    # the caller to modify the output without modifying the +attr+ hash.
    def html_attributes(attr, overrides = nil)
      return '' if (!attr || attr.empty?) && !overrides

      result = +''
      attr&.each_with_object(result) do |(k, v), result|
        next if v.nil? || (k == 'id' && v.strip.empty?) || overrides&.key?(k)
        result << " #{k}=\"#{escape_html(v.to_s)}\""
      end
      overrides&.each_with_object(result) do |(k, v), result|
        result << " #{k}=\"#{escape_html(v.to_s)}\""
      end
      result
    end

    ESCAPE_MAP = { #:nodoc:
      '<' => '&lt;',
      '>' => '&gt;',
      '&' => '&amp;',
      '"' => '&quot;',
    }

    # Escapes the special HTML characters in the string +str+.
    def escape_html(str)
      str.gsub(/<|>|&|"/, ESCAPE_MAP)
    end

  end

end
