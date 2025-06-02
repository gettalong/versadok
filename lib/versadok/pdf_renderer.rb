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

require 'erb'
require 'yaml'
require_relative 'renderer'
require_relative 'utils'
require_relative 'data_dir'
require 'hexapdf'

module VersaDok

  # The PDF renderer takes a VersaDok AST and creates a PDF document using HexaPDF.
  #
  # See: HexaPDF - https://hexapdf.gettalong.org
  #
  # == Usage
  #
  # The easiest use is by calling #render with just the root Node. This returns a HexaPDF::Composer
  # instance that has been used to create the document. Styling of the document is done via themes
  # (either a predefined one or a custom one).
  #
  # If something more advanced is needed, it is possible to pass a HexaPDF::Document::Layout
  # instance to the #render method. If this is done, no styling is performed and the result of the
  # method is either a single HexaPDF box instance or an array of them (depending on the node passed
  # in). This allows for integrating multiple separate ASTs into a single output document.
  #
  # == Styling
  #
  # Styling is done via a theme file in YAML format. Each key describes a style name and the value
  # is a hash of HexaPDF::Layout::Style properties. In contrast to other styling systems like CSS
  # there is no built-in inheritance: Only one style is applied. However, the :base key can be used
  # to specify the base style from which style properties should be copied.
  #
  # Each unique node type (see Node#unique_type) has an associated default style. For example, a
  # paragraph is styled via the "paragraph" style and a level 3 header via the "header3" style.
  #
  # It is also possible to apply specific styling based on the block node nesting. For example, if a
  # paragraph is nested inside a blockquote, the "blockquote_paragraph" style would be applied
  # instead of the "paragraph" style.
  #
  # Additionally, the text content of a block element can be styled by appending "_text" to the
  # block style name, e.g. "paragraph_text", "header3_text" or "blockquote_paragraph_text".
  class PDFRenderer < Renderer

    using Utils::HashDeepMerge

    def initialize(*) #:nodoc:
      super
      @stack = []
      @stack_unique_types = []
      @style_overrides = []
    end

    # Renders the given +node+ into a PDF document.
    #
    # There are two modes:
    #
    # 1. If +layout+ is not specified, a HexaPDF::Composer instance is created and #set_up_styles is
    #    called. Then the node tree is rendered using this composer instance. Finally, the composer
    #    instance is returned.
    #
    # 2. If +layout+ is specified, #set_up_styles is not called. The +layout+ object is used for
    #    rendering the node tree and the result (either a single HexaPDF:::Layout::Box object or an
    #    array of such boxes) is returned.
    #
    # In both cases the PDF document itself is not written, this is the job of the caller.
    def render(node, layout: nil)
      if layout
        @layout = layout
      else
        @composer = HexaPDF::Composer.new(skip_page_creation: true)
        @layout = @composer.document.layout
        set_up_styles(@composer.document)
        @composer.page_style(:default, page_size: :A4, orientation: :portrait) do |canvas, style|
          style.frame = style.create_frame(canvas.context, 36)
        end
      end

      @stack.clear
      @stack_unique_types.clear
      @style_overrides.clear
      result = if node.type == :root
                 render_root(node)
               else
                 super(node)
               end

      if layout
        result
      else
        @composer.new_page
        Array(result).each {|box| @composer.draw_box(box) }
        @composer
      end
    end

    # Sets up the styles needed for rendering in the given HexaPDF::Document.
    #
    # This uses the built-in default styling of the elements.
    def set_up_styles(document)
      theme = ERB.new(File.read(File.join(VersaDok.data_dir, 'themes', 'default.yaml'))).result
      theme = YAML.safe_load(theme, permitted_classes: [Symbol], symbolize_names: true)
      document.layout.styles(**theme)
    end

    private

    # Renders the given +node+.
    #
    # Before the node is rendered, it is pushed onto the stack and afterwards it is removed from the
    # stack. This allows using the node hierarchy for decisions.
    def render_node(node)
      @stack.push(node)
      @stack_unique_types.push(node.unique_type)
      result = super
      @stack_unique_types.pop
      @stack.pop
      result
    end

    # Renders a paragraph via HexaPDF's +formatted_text+ helper.
    def render_paragraph(para)
      @layout.formatted_text(render_children(para), box_style: node_style)
    end

    # Renders a header via HexaPDF's +formatted_text+ helper.
    def render_header(header)
      @layout.formatted_text(render_children(header), box_style: node_style)
    end

    # Renders a blockquote by putting all child nodes into a container for styling.
    def render_blockquote(blockquote)
      @layout.container(splitable: true, style: node_style) do |container|
        render_children(blockquote, container)
      end
    end

    # Renders a list via HexaPDF's built-in list box.
    def render_list(list)
      @layout.list(start_number: list[:start] || 1, style: node_style) do |container|
        render_children(list, container)
      end
    end

    # Renders a code block via HexaPDF's +text+ helper.
    def render_code_block(code_block)
      @layout.text(code_block.content, style: text_style(append_text_suffix: true),
                   box_style: node_style)
    end

    # Renders a general block by putting all child nodes into a container for styling.
    def render_general_block(block)
      @layout.container(splitable: true, style: node_style) do |container|
        render_children(block, container)
      end
    end

    # Returns a hash that styles the given +text+.
    #
    # The return value is then used as item in the array passed to HexaPDF's +formatted_text+
    # helper.
    def render_text(text)
      {text: text.content, style: text_style}
    end

    # Returns a single space character.
    #
    # See: #render_text
    def render_soft_break(_node)
      " "
    end

    # Returns a line feed character.
    #
    # See: #render_text
    def render_hard_break(_node)
      "\n"
    end

    # Returns a hash that styles the given +verbatim_text+ as verbatim.
    #
    # See: #render_text
    def render_verbatim(verbatim_text)
      {text: verbatim_text.content, style: text_style}
    end

    ['span', 'strong', 'emphasis', 'subscript', 'superscript'].each do |node_type|
      define_method("render_#{node_type}") do |node|
        render_children(node)
      end
    end

    # Sets a style override for the link itself and returns the rendered children.
    def render_link(link)
      if link[:destination]
        @style_overrides.push(overlays: {link: {uri: link[:destination]}})
      elsif (dest = @context.link_destinations[link[:reference]])
        @style_overrides.push(overlays: {link: {uri: dest}})
      end
      result = render_children(link)
      @style_overrides.pop if link[:destination]
      result
    end

    # Returns an inline box wrapping an image box.
    #
    # The image must have either the width and/or the height set. Otherwise the height is adjusted
    # according to the font size.
    def render_image(image)
      path = image[:destination] || @context.link_destinations[image[:reference]]
      return unless path && File.exist?(path)

      width = image.attributes&.[]('width').to_i
      height = image.attributes&.[]('height').to_i
      height = text_style.scaled_font_ascender if width == 0 && height == 0
      @layout.inline_box(@layout.image(path, width: width, height: height, style: node_style))
    end

    # Returns the appropriate HexaPDF::Layout::Style instance for the current node.
    #
    # See the class documentation for details.
    def node_style
      full_style_name = @stack_unique_types.join('_').intern
      if @layout.style?(full_style_name)
        @layout.style(full_style_name)
      else
        @layout.style(full_style_name, base: @stack_unique_types.last)
      end
    end

    # Returns the appropriate HexaPDF::Layout::Style instance for the current text-based node.
    def text_style(append_text_suffix: false)
      full_style_name = @stack_unique_types.join('_')
      full_style_name << "_text" if append_text_suffix
      full_style_name = full_style_name.intern

      if @layout.style?(full_style_name)
        style = @layout.style(full_style_name)
      else
        block_index = @stack.rindex {|node| node.category == :block } || 0
        block_style_name = "#{@stack_unique_types[0..block_index].join('_')}_text".intern
        parent_style = if @layout.style?(block_style_name)
                         block_style_name
                       else
                         block_style_name = "#{@stack_unique_types[block_index]}_text".intern
                         if @layout.style?(block_style_name)
                           block_style_name
                         else
                           :base_text
                         end
                       end
        style = @layout.style(full_style_name, base: parent_style)
        @stack_unique_types[(block_index + 1)..-1].each do |unique_type|
          style.merge(@layout.style(unique_type)) if @layout.style?(unique_type)
        end
      end

      unless @style_overrides.empty?
        style = style.dup
        @style_overrides.each {|hash| style.update(**hash) }
      end

      @layout.resolve_font(style)

      style
    end

    # Renders the children of the +node+.
    #
    # If +container+ is given, each child node is rendered via #render_node and a non-nil result is
    # added to the +container+ via #<<.
    #
    # If +container+ is not given, the results of calling #render_node for each child are put into a
    # compacted flat array and this array is returned.
    def render_children(node, container = nil)
      if container
        node.children.each do |child|
          result = render_node(child)
          container << result if result
        end
      else
        node.children.flat_map {|child| render_node(child) }.compact
      end
    end

  end

end
