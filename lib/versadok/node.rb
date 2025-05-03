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

  # A Node encapsulates all information for an element in the abstract syntax tree.
  #
  # == Supported block node types
  #
  # === root
  #
  # Content:: Block elements
  #
  # The root element represents the root of the abstract syntax tree. It is just the container for
  # the main block elements of a document.
  #
  # === blockquote
  #
  # Content:: Block elements
  #
  # The blockquote element represents an extended quotation and contains block elements.
  #
  # === list
  #
  # Content:: Special (only list_item elements)
  #
  # The list element represents an ordered or unordered list. It must have at least one list_item as
  # child.
  #
  # The property :marker specifies the type of the list: :asterisk, :plus, :minus, or :decimal.
  #
  # In case of a :decimal list the :start property defines the number for the first list item.
  #
  # === list_item
  #
  # Content:: Block elements
  #
  # The list_item element represents a single list item in an ordered or unordered list.
  #
  # === header
  #
  # Content:: Inline elements
  #
  # The header element represents heading text of a certain level.
  #
  # The :level property needs to be set to the header level, 1 to 6.
  #
  # === paragraph
  #
  # Content:: Inline elements
  #
  # The paragraph element represents a single paragraph containing inline elements.
  #
  # === block_extension
  #
  # Content:: Block elements
  #
  # The block_extension element represents a block extension for adding custom functionality.
  #
  # The property +:name+ contains the name of the extension.
  #
  #
  # == Supported inline node types
  #
  # === strong
  #
  # Content:: Inline elements
  #
  # The strong element represents part of the text that is visually marked up to stand out, usually
  # using bold face.
  #
  # === emphasis
  #
  # Content:: Inline elements
  #
  # The emphasis element represents part of a text that is slightly emphasized, usually by using an
  # italic face.
  #
  # === subscript
  #
  # Content:: Inline elements
  #
  # The subscript element represents text that is below the normal text line.
  #
  # === superscript
  #
  # Content:: Inline elements
  #
  # The superscript element represents text that is above the normal text line.
  #
  # === text
  #
  # Content:: Text
  #
  # The text element represents the text itself and therefore contains no other elements.
  #
  # The text itself is stored via the #content accessor.
  #
  # === verbatim
  #
  # Content:: Verbatim text
  #
  # The verbatim element represents verbatim text that is not processed and reproduced as is.
  #
  # The verbatim text is stored via the #content accessor.
  #
  # === link
  #
  # Content:: Inline elements
  #
  # The link element represents a link to another location, either locally in the same document or
  # to another document.
  #
  # The destination of the link is specified with one of the following two properties:
  #
  # * The property +:destination+ is used when specifying the link destination directly.
  #
  # * The property +:reference+ is used to specify the reference name under which the link
  #   destination is stored.
  #
  # === span
  #
  # Content:: Inline elements
  #
  # The span element represents a marked-up part of the text that has additional attributes.
  #
  # === temp_data
  #
  # Content:: Verbatim text
  #
  # The temp_data element is temporarily used during parsing for storing the reference, destination
  # and attribute list parts.
  #
  # This element must never appear in the final AST.
  #
  # === soft_break
  #
  # Content:: None
  #
  # The soft_break element represents a soft line break, i.e. a line break in the source that should
  # not be visible in the output.
  #
  # === hard_break
  #
  # Content:: None
  #
  # The hard_break element represents a hard line break, i.e. a line break in the source that should
  # be visible in the output.
  #
  # === inline_extension
  #
  # Content:: Inline elements
  #
  # The inline_extension element represents an inline extension for adding custom functionality.
  #
  # The property +:name+ contains the name of the extension.
  class Node

    CATEGORY_MAP = { #:nodoc:
      root: :block,
      blockquote: :block,
      list_item: :block,
      header: :block,
      paragraph: :block,
      block_extension: :block,
      strong: :inline,
      emphasis: :inline,
      subscript: :inline,
      superscript: :inline,
      text: :inline,
      verbatim: :inline,
      link: :inline,
      span: :inline,
      temp_data: :inline,
      soft_break: :inline,
      hard_break: :inline,
      inline_extension: :inline,
    }

    CONTENT_MODEL_MAP = { #:nodoc:
      root: :block,
      blockquote: :block,
      list_item: :block,
      header: :inline,
      paragraph: :inline,
      block_extension: :block,
      strong: :inline,
      emphasis: :inline,
      subscript: :inline,
      superscript: :inline,
      text: :text,
      verbatim: :verbatim,
      link: :inline,
      span: :inline,
      temp_data: :verbatim,
      soft_break: :none,
      hard_break: :none,
      inline_extension: :inline,
    }

    # The type of the node.
    attr_accessor :type

    # The content of the node. Can be +nil+ if it has no content.
    attr_accessor :content

    # The hash with the node attributes. Can be +nil+ in case the node has no attributes.
    #
    # The keys and values need to be strings.
    attr_accessor :attributes

    # The processing properties of the node.
    #
    # These properties can be used by the parser and/or the renderer for their purposes.
    #
    # Also see #[] and #[]=.
    attr_accessor :properties

    # Creates a new Node instance with the given +type+.
    #
    # All other arguments are optional.
    def initialize(type, content: nil, attributes: nil, properties: nil)
      @type = type
      @content = content
      @attributes = attributes
      @properties = properties
      @children = nil
    end

    # Returns the children array.
    def children
      @children ||= []
    end

    # Adds the given +node+ to the children array and returns self.
    def <<(node)
      children << node
      self
    end

    # Returns the category of the node, either :block or :inline.
    #
    # The category of a node is fixed by the node's type.
    def category
      CATEGORY_MAP[@type]
    end

    # Returns the content model of the node, either :block, :inline, :text, :verbatim, :special, or
    # :none.
    #
    # The content model of a node is fixed by the node's type.
    def content_model
      CONTENT_MODEL_MAP[@type]
    end

    # Returns the unique type name of the node.
    #
    # The unique type is either the #type itself or in case of :header the type plus the header
    # level and in case of :list the type plus the list marker name.
    def unique_type
      case type
      when :header then :"header#{self[:level]}"
      when :list then :"list_#{self[:marker]}"
      else type
      end
    end

    # Returns the property value for the given +key+.
    def [](key)
      properties && properties[key]
    end

    # Sets the property +key+ to the given +value+.
    def []=(key, value)
      (@properties ||= {})[key] = value
    end

    # Returns a simple string representation of the node and its children.
    def to_s(indent = 0)
      str = "#{' ' * indent}#{@type} #{content && content.inspect} #{properties&.inspect} " \
            "#{@attributes&.map {|k,v| "#{k}=#{v.inspect}"}&.join(' ')}".rstrip
      str << "\n#{@children.map {|c| c.to_s(indent + 2)}.join("\n")}" unless children.empty?
      str
    end

  end

end
